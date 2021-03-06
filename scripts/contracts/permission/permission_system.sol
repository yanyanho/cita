pragma solidity ^0.4.18;

import "./permission_sys_interface.sol";
import "./permission_check.sol";

/// @notice TODO: Multiple routers
///             : More modifier
///             : Mark resource
///             : Role tree
///             : Change bytes32 to uint8 of the permissions using enum and array
///             : Check the adding permissions is valid
/// @title Permission system of CITA
contract PermissionSystem is PermissionSysInterface, PermissionCheck {

    /// @dev Setup
    /// @param _superAdmin The address of superAdmin
    /// @param _adamEve Address as Adam and EVe of the permission system world.
    ///                 These address will have the basic permission
    function PermissionSystem(address _superAdmin, address[] _adamEve) public {
        // User can give up it by setting address 0x0
        if (address(0x0) != _superAdmin)
            superAdmin = _superAdmin; 
        else if(!Util.addressArrayNul(_adamEve))
            // Call the genesis 
            genesis(_adamEve);
        else
            revert();
    }

    /// @dev Init group only by superAdmin
    function initGroup(bytes32 _root, address[] _adamEve, bool _subSwitch)
        public
        onlySuperAdmin
        groupNul(_root)
        returns (bool)
    {
        GroupInited(_root, _adamEve, _subSwitch);
        group_names.push(_root);
        return GroupManager.initGroup(groups, _root, _adamEve, _subSwitch);
    }

    /// @dev Init role only by superAdmin
    function initRole(bytes32 _basic, bytes32[] _permissions)
        public
        onlySuperAdmin
        roleNul(_basic)
        returns (bool)
    {
        RoleInited(_basic, _permissions);
        role_names.push(_basic);
        return RoleManager.initRole(roles, _basic, _permissions);
    }

    /// @dev Init authorization only by superAdmin
    function initAuthorization(bytes32 _group, bytes32 _role)
        public
        onlySuperAdmin
        authNul(_group, _role)
        returns (bool)
    {
        AuthorizationInited(_group, _role);
        auth.role_groups[_role].push( _role);
        auth.group_roles[_group].push(_group);
        return true; 
    }

    /// @dev Apply to join the group
    /// @notice TODO: check the SendTx permission.
    function applyGroup(bytes32 _group) public returns (bool) {
        group_applicants[_group].push(msg.sender);
        GroupApplied(msg.sender, _group);
        return true;
    }

    /// @dev Approve the application of joining the _group
    function approveApply(bytes32 _group, bytes32 _resource, bytes32 _role)
        public
        can(msg.sender, _group, _resource, _role, bytes32("UpdateGroup"))
        returns (bool)
    {
        ApplyApproved(msg.sender, _group, _resource, _role);
        return GroupManager.addUsers(groups, _group, group_applicants[_group]);
    }

    /// @dev Grant the role to users
    function grantRole(bytes32 _group, bytes32 _resource, bytes32 _role, address[] _users)
        public
        // Default resourceGroup is userGroup
        can(msg.sender, _group, _group, _role, bytes32("UpdateGroup"))
        returns (bool)
    {
        RoleGranted(_group, _resource, _role, _users);
        return GroupManager.addUsers(groups, _resource, _users);
    }

    /// @dev Revoke the users's role
    function revokeRole(bytes32 _group, bytes32 _resource, bytes32 _role, address[] _users)
        public
        can(msg.sender, _group, _resource, _role, bytes32("UpdateGroup"))
        returns (bool)
    {
        RoleRevoked(_group, _resource, _role, _users);
        return GroupManager.deleteUsers(groups, _group, _users);
    }

    /// @dev Apply to quit the group
    function quitGroup(bytes32 _group)
        public
        userInGroup(msg.sender, _group)
        returns (bool)
    {
        GroupQuitted(msg.sender, _group);
        return Util.addressDelete(msg.sender, group_resignations[_group]);
    }

    /// @dev Approve the application of quitting the group
    /// @notice Msg.sender should belong to the father node
    function approveQuit(bytes32 _group, bytes32 _resource, bytes32 _role)
        public
        can(msg.sender, _group, _resource, _role, bytes32("UpdateGroup"))
        returns (bool)
    {
        QuitApproved(msg.sender, _group, _resource, _role);
        return GroupManager.deleteUsers(groups, _group, group_resignations[_group]); 
    }

    /// @dev New a group
    /// @param _group The group of the caller
    function newGroup(
        bytes32 _group,
        bytes32 _newName,
        address[] _newUsers,
        bool _newSubSwitch,
        uint8 _op,
        bytes32 _role,
        string _profile
    )
        public 
        nameNotExist(_newName, group_names)
        can(msg.sender, _group, _group, _role, bytes32("CreateGroup"))
        returns (bool)
    {
        return _newGroup(_group, _newName, _newUsers, _newSubSwitch, _op, _profile);
    }

    /// @dev Delete group
    /// @notice Delete a tree's node. Only leaf node
    function deleteGroup(bytes32 _group, bytes32 _resource, bytes32 _role)
        public
        nameExist(_group, group_names)
        can(msg.sender, _group, _resource, _role, bytes32("DeleteGroup"))
        leafNode(_group)
        returns (bool)
    {
        // Delete the name in group 
        if (GroupManager.deleteGroup(groups, _group))
            // Delete the name in authorization
            if (AuthorizationManager.deleteGroup(auth, _group))
                // Delete the name in group_names
                if (Util.bytes32Delete(_group, group_names))
                    return true;
    }

    /// @dev Modify the group name
    function modifyGroupName(bytes32 _oldName, bytes32 _newName, bytes32 _resource, bytes32 _role)
        public 
        nameNotExist(_newName, group_names)
        can(msg.sender, _oldName, _resource, _role, bytes32("UpdateGroup"))
        returns (bool)
    {
        // Change the name in group 
        if (GroupManager.modifyName(groups, _oldName, _newName))
            // Change the name in authorization
            if (AuthorizationManager.replaceGroup(auth, _oldName, _newName))
                // Change the name in group_names
                if (Util.bytes32Replace(_oldName, _newName, group_names))
                    return true;
    }

    /// @dev Modify the sub_switch
    function modifySubSwitch(
        bytes32 _group,
        bytes32 _resource,
        bytes32 _role,
        bool _newSubSwitch
    )
        public 
        can(msg.sender, _group, _resource, _role, bytes32("UpdateGroup"))
        returns (bool)
    {
        return GroupManager.modifySubSwitch(groups, _group, _newSubSwitch);
    }

    /// @dev New a role
    /// @param _group The group of the caller
    /// @param _role The role of the caller
    function newRole(
        bytes32 _group,
        bytes32 _newName,
        bytes32 _role,
        bytes32[] _newPermissions,
        uint8 _op
    )
        public
        nameNotExist(_newName, role_names)
        permissionsInRole(_newPermissions, _role)
        can(msg.sender, _group, _group, _role, bytes32("CreateRole"))
        returns (bool) 
    {
        return _newRole(_group, _newName,  _newPermissions, _op);
    }
 
    /// @dev Delete role
    function deleteRole(bytes32 _role, bytes32 _group, bytes32 _resource)
        public 
        nameExist(_role, role_names)
        can(msg.sender, _group, _resource, _role, bytes32("CreateRole"))
        returns (bool)
    {
        // Delete the name in role
        if (RoleManager.deleteRole(roles, _role))
            // Delete the name in authorization
            if (AuthorizationManager.deleteRole(auth, _role))
                // Delete the name in role_names
                if (Util.bytes32Delete(_role, role_names))
                    return true;
    }

    /// @dev Modify the role name
    function modifyRoleName(bytes32 _oldName, bytes32 _newName, bytes32 _group, bytes32 _resource)
        public
        nameNotExist(_newName, role_names)
        can(msg.sender, _group, _resource, _oldName, bytes32("UpdateRole"))
        returns (bool)
    {
        // Change the name in role 
        if (RoleManager.modifyName(roles, _oldName, _newName))
            // Change the name in authorization
            if (AuthorizationManager.replaceRole(auth, _oldName, _newName))
                // Change the name in role_names
                if (Util.bytes32Replace(_oldName, _newName, role_names))
                    return true;
    }

    /// @dev Add permissions 
    function addPermissions(bytes32 _role, bytes32[] _permissions, bytes32 _group, bytes32 _resource)
        public 
        nameExist(_role, role_names)
        can(msg.sender, _group, _resource, _role, bytes32("UpdateRole"))
        returns (bool)
    {
        return RoleManager.addPermissions(roles, _role, _permissions);
    }

    /// @dev Delete permissions 
    function deletePermissions(bytes32 _role, bytes32[] _permissions, bytes32 _group, bytes32 _resource)
        public 
        can(msg.sender, _group, _resource, _role, bytes32("UpdateRole"))
        returns (bool)
    {
        return RoleManager.deletePermissions(roles, _role, _permissions);
    }

    /// @dev Set authorization
    function setAuthorization(bytes32 _group, bytes32 _role, bytes32 _resource)
        public 
        can(msg.sender, _group, _resource, _role, bytes32("CreateAuth"))
        returns(bool)
    {
        return AuthorizationManager.setAuthorization(auth, _group, _role);  
    }

    /// @dev Cancel authorization
    function cancelAuthorization(bytes32 _group, bytes32 _role, bytes32 _resource)
        public 
        can(msg.sender, _group, _resource, _role, bytes32("DeteleAuth"))
        returns(bool)
    {
        return AuthorizationManager.cancelAuthorization(auth, _group, _role);  
    }

    /// @dev Query the role of the group
    function queryRole(bytes32 _group)
        view
        public
        returns (bytes32[])
    {
        return auth.group_roles[_group];
    }

    /// @dev Query the permissions 
    function queryPermissions(bytes32 _role)
        view
        public
        returns (bytes32[])
    {
        return roles.roles[_role].permissions;
    }

    /// @dev Query the the groups of the user
    function queryGroup(address _user)
        view
        public
        returns (bytes32[])
    {
        return user_groups[_user];
    }

    /// @dev Query the users
    function queryUsers(bytes32 _group)
        view
        public
        returns (address[])
    {
        return groups.groups[_group].users;
    }

    /// @dev Query the subGroups
    function querySubGroups(bytes32 _group)
        view
        public
        returns (bytes32[])
    {
        return groups.groups[_group].subGroups;
    }

    /// @dev Query the subSwitch
    function querySubSwitch(bytes32 _group)
        view
        public
        returns (bool)
    {
        return groups.groups[_group].subSwitch;
    }

    // Create the genensis: group, role and authorization when the superAdmin is nul
    function genesis(address[] _adamEve)
        private
    {
        // Init the group. 
        _initGroup(bytes32("root"), _adamEve);
        // Init the role
        _initRole(bytes32("basic"));
        // Init the authorization
        _initAuthorization(bytes32("root"), bytes32("basic"));
    }

    /// @dev Init group: root
    function _initGroup(bytes32 _root, address[] _adamEve)
        private 
        returns (bool)
    {
        group_names.push(_root);
        // Set subSwitch false by default
        return GroupManager.initGroup(groups, _root, _adamEve, false);
    }

    /// @dev Init role: basic 
    function _initRole(bytes32 _basic)
        private 
        returns (bool)
    {
        _per_basic.push(bytes32("SendTx"));
        _per_basic.push(bytes32("CreateGroup"));
        _per_basic.push(bytes32("CreateRole"));
        _per_basic.push(bytes32("CreateAuth"));
        role_names.push(_basic);
        return RoleManager.initRole(roles, _basic, _per_basic);
    }

    /// @dev Init gengesis's authorization: root group and basic role
    function _initAuthorization(bytes32 _group, bytes32 _role)
        private
        returns (bool)
    {
        auth.role_groups[_role].push( _role);
        auth.group_roles[_group].push(_group);
        return true; 
    }

    /// @dev New a role
    function _newRole(
        bytes32 _group,
        bytes32 _newName,
        bytes32[] _newPermissions,
        uint8 _op
    )
        private
        returns (bool)
    {
        role_names.push(_newName);
        return RoleManager.newRole(roles, _group, _newName, _newPermissions, Util.SetOp(_op));
    }

    /// @dev New a group 
    function _newGroup(
        bytes32 _group,
        bytes32 _newName,
        address[] _newUsers,
        bool _newSubSwitch,
        uint8 _op,
        string _profile
    )
        private
        returns (bool)
    {
        group_names.push(_newName);
        return GroupManager.newGroup(groups, _group, _newName, _newUsers, _newSubSwitch, Util.SetOp(_op), _profile);
    }
}
