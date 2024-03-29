#!/usr/bin/python
# coding: utf-8 -*-

# (c) 2017, Wayne Witzel III <wayne@riotousliving.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import absolute_import, division, print_function
__metaclass__ = type


ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'community'}


DOCUMENTATION = '''
---
module: tower_host
version_added: "2.3"
author: "Wayne Witzel III (@wwitzel3)"
short_description: create, update, or destroy Ansible Tower host.
description:
    - Create, update, or destroy Ansible Tower hosts. See
      U(https://www.ansible.com/tower) for an overview.
options:
    name:
      description:
        - The name to use for the host.
      required: True
    description:
      description:
        - The description to use for the host.
    inventory:
      description:
        - Inventory the host should be made a member of.
      required: True
    enabled:
      description:
        - If the host should be enabled.
      type: bool
      default: 'yes'
    variables:
      description:
        - Variables to use for the host. Use C(@) for a file.
    state:
      description:
        - Desired state of the resource.
      choices: ["present", "absent"]
      default: "present"
    groups:
      description:
        - Groups to be associated to Host
      version_added: "2.8"
extends_documentation_fragment: tower
'''


EXAMPLES = '''
- name: Add tower host
  tower_host:
    name: localhost
    description: "Local Host Group"
    inventory: "Local Inventory"
    state: present
    tower_config_file: "~/tower_cli.cfg"
- name: Associate tower host to groups
  tower_host:
    name: localhost
    description: "Local Host Group"
    inventory: "Local Inventory"
    groups: group_name1, group_name2
    state: present
    tower_config_file: "~/tower_cli.cfg"
'''


import os

from ansible.module_utils.ansible_tower import TowerModule, tower_auth_config, tower_check_mode, HAS_TOWER_CLI

try:
    import tower_cli
    import tower_cli.utils.exceptions as exc

    from tower_cli.conf import settings
except ImportError:
    pass


def associate_host_to_group(name, groups, host, inv, json_output):
    group_obj = tower_cli.get_resource('group')
    host_res = host.get(inventory=inv['id'], name=name)
    for group in groups:
        group_res = group_obj.get(inventory=inv['id'], name=group.strip())
        changed = host.associate(host=host_res['id'], group=group_res['id'])
        if changed['changed'] is True:
            json_output['group_added'] = group.strip()
            return True
    return False

def main():
    argument_spec = dict(
        name=dict(required=True),
        description=dict(),
        inventory=dict(required=True),
        enabled=dict(type='bool', default=True),
        variables=dict(),
        groups=dict(type='list'),
        state=dict(choices=['present', 'absent'], default='present'),
    )
    module = TowerModule(argument_spec=argument_spec, supports_check_mode=True)

    name = module.params.get('name')
    description = module.params.get('description')
    inventory = module.params.get('inventory')
    enabled = module.params.get('enabled')
    state = module.params.get('state')

    groups = module.params.get('groups')
    variables = module.params.get('variables')
    if variables:
        if variables.startswith('@'):
            filename = os.path.expanduser(variables[1:])
            with open(filename, 'r') as f:
                variables = f.read()

    json_output = {'host': name, 'state': state}

    tower_auth = tower_auth_config(module)
    with settings.runtime_values(**tower_auth):
        tower_check_mode(module)
        host = tower_cli.get_resource('host')

        try:
            inv_res = tower_cli.get_resource('inventory')
            inv = inv_res.get(name=inventory)

            if state == 'present':
                result = host.modify(name=name, inventory=inv['id'], enabled=enabled,
                                     variables=variables, description=description, create_on_missing=True)
                json_output['id'] = result['id']
                if groups:
                    result['changed'] = associate_host_to_group(name, groups, host, inv, json_output)

            elif state == 'absent':
                result = host.delete(name=name, inventory=inv['id'])
        except (exc.NotFound) as excinfo:
            module.fail_json(msg='Failed to update host, inventory not found: {0}'.format(excinfo), changed=False)
        except (exc.ConnectionError, exc.BadRequest) as excinfo:
            module.fail_json(msg='Failed to update host: {0}'.format(excinfo), changed=False)

    json_output['changed'] = result['changed']
    module.exit_json(**json_output)


if __name__ == '__main__':
    main()