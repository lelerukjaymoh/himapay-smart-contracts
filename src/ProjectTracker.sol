// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin-upgradeable/security/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";

contract ProjectTracker is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    /*///////////////////////////////////////////////////////////////
                            State variables / Mappings
    //////////////////////////////////////////////////////////////*/

    // @dev the Role that allows a user to pause or unpause the contract
    bytes32 public immutable PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public immutable ADMIN_ROLE = keccak256("ADMIN_ROLE");

    error RevertWithError(string reason);

    enum ProjectStatus {
        InProgress,
        Completed,
        Cancelled
    }

    enum MilestoneStatus {
        InProgress,
        Completed,
        Cancelled
    }

    struct Project {
        uint256 deadline;
        uint256 createdAt;
        uint256 updatedAt;
        uint256 completedAt;
        uint256 projectId;
        uint256 clientId;
        uint256 developerId;
        uint64 totalTasksCompleted;
        uint64 totalTasks;
        ProjectStatus status;
        uint256 cost;
    }

    struct ProjectMilestone {
        uint256 milestoneId;
        Project projectId;
        uint256 createdAt;
        uint256 updatedAt;
        MilestoneStatus status;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => ProjectMilestone) public projectMilestones;

    /*///////////////////////////////////////////////////////////////
                            Initializer
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     */
    function initialize() public initializer {
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    event NewProject(
        uint256 projectId,
        uint256 deadline,
        uint256 createdAt,
        uint256 updatedAt,
        uint256 completedAt,
        uint64 totalTasks,
        uint256 clientId,
        uint256 developerId,
        uint64 totalTasksCompleted,
        ProjectStatus status,
        uint256 cost
    );

    event MilestoneCompleted(
        uint256 milestoneId,
        uint256 updatedAt,
        MilestoneStatus status
    );

    event NewMilestone(
        uint256 milestoneId,
        Project projectId,
        uint256 createdAt
    );

    event MilestoneDeleted(uint256 milestoneId);

    event ProjectClientChanged(
        uint256 previousClientId,
        uint256 newClientId,
        uint256 projectId
    );

    event ProjectDeveloperChanged(
        uint256 previousDeveloperId,
        uint256 newDeveloperId,
        uint256 projectId
    );

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    modifier isNewProject(uint256 _projectId) {
        require(
            projects[_projectId].projectId == 0,
            "Project with this ID already exists"
        );
        _;
    }

    modifier validDeadline(uint256 _deadline) {
        require(_deadline > block.timestamp, "Deadline cannot be in the past");
        _;
    }

    modifier milestoneExists(uint256 _milestoneId) {
        require(
            projectMilestones[_milestoneId].milestoneId != 0,
            "Milestone with this ID does not exist"
        );
        _;
    }

    modifier milestoneNotCompleted(uint256 _milestoneId) {
        require(
            projectMilestones[_milestoneId].status != MilestoneStatus.Completed,
            "Milestone with this ID has already been completed"
        );
        _;
    }

    modifier milestoneDoesNotExist(uint256 _milestoneId) {
        require(
            projectMilestones[_milestoneId].milestoneId == 0,
            "Milestone with this ID already exists"
        );
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            External functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Pauses all interactions with this contract
     *
     * Requirements:
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all interactions with this contract.
     *
     * Requirements:
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function createProject(
        uint256 _projectId,
        uint256 _deadline,
        uint256 _updatedAt,
        uint256 _completedAt,
        uint64 _totalTasks,
        uint64 _clientId,
        uint64 _developerId,
        uint64 _cost,
        uint[] memory _milestones
    )
        external
        onlyRole(ADMIN_ROLE)
        validDeadline(_deadline)
        isNewProject(_projectId)
    {
        /**
         * @dev Ensure the following requirements are met
         *
         * Requirements:
         * - Project ID cannot be 0
         * - Total tasks cannot be 0
         * - Cost cannot be 0
         */
        if (_projectId == 0) revert RevertWithError("Project ID cannot be 0");

        if (_totalTasks == 0) revert RevertWithError("Total tasks cannot be 0");

        if (_cost == 0) revert RevertWithError("Cost cannot be 0");

        uint totalMilestones = _milestones.length;
        for (uint i; i < totalMilestones; ) {
            _createMilestone(_milestones[i], _projectId);

            unchecked {
                ++i;
            }
        }

        Project memory project = Project({
            projectId: _projectId,
            deadline: _deadline,
            createdAt: block.timestamp,
            updatedAt: _updatedAt,
            completedAt: _completedAt,
            totalTasks: _totalTasks,
            clientId: _clientId,
            developerId: _developerId,
            totalTasksCompleted: 0,
            status: ProjectStatus.InProgress,
            cost: _cost
        });

        emit NewProject(
            project.projectId,
            project.deadline,
            project.createdAt,
            project.updatedAt,
            project.completedAt,
            project.totalTasks,
            project.clientId,
            project.developerId,
            project.totalTasksCompleted,
            project.status,
            project.cost
        );
    }

    /*
                            Milestone functions
    //////////////////////////////////////////////////////////////*/
    function completeMilestone(
        uint milestoneId,
        uint projectId
    )
        external
        onlyRole(ADMIN_ROLE)
        milestoneExists(milestoneId)
        milestoneNotCompleted(milestoneId)
    {
        ProjectMilestone storage milestone = projectMilestones[milestoneId];

        milestone.status = MilestoneStatus.Completed;
        milestone.updatedAt = block.timestamp;

        // Update project
        Project storage project = projects[projectId];

        /// @dev possibility of an overflow is low, but still possible
        unchecked {
            project.totalTasksCompleted += 1;
        }

        if (project.totalTasksCompleted == project.totalTasks) {
            project.status = ProjectStatus.Completed;
        }

        project.completedAt = block.timestamp;

        emit MilestoneCompleted(
            milestone.milestoneId,
            milestone.updatedAt,
            milestone.status
        );
    }

    function createMilestone(
        uint256 _milestoneId,
        uint256 _projectId
    ) external milestoneDoesNotExist(_milestoneId) onlyRole(ADMIN_ROLE) {
        _createMilestone(_milestoneId, _projectId);
    }

    function deleteMilestone(
        uint milestoneId
    ) external onlyRole(ADMIN_ROLE) milestoneExists(milestoneId) {
        delete projectMilestones[milestoneId];

        emit MilestoneDeleted(milestoneId);
    }

    /*
                            Project functions
    //////////////////////////////////////////////////////////////*/
    function getProjectProgress(
        uint projectId
    ) external view returns (uint64, uint64) {
        Project storage project = projects[projectId];

        return (project.totalTasksCompleted, project.totalTasks);
    }

    function updateProjectClient(
        uint projectId,
        uint newClientId
    ) external onlyRole(ADMIN_ROLE) {
        Project storage project = projects[projectId];
        uint previousClientId = project.clientId;

        project.clientId = newClientId;

        emit ProjectClientChanged(previousClientId, newClientId, projectId);
    }

    function updateProjectDeveloper(
        uint projectId,
        uint newDeveloperId
    ) external onlyRole(ADMIN_ROLE) {
        Project storage project = projects[projectId];
        uint previousDeveloperId = project.developerId;

        project.developerId = newDeveloperId;

        emit ProjectDeveloperChanged(
            previousDeveloperId,
            newDeveloperId,
            projectId
        );
    }

    /*///////////////////////////////////////////////////////////////
                            Internal functions
    //////////////////////////////////////////////////////////////*/

    function _createMilestone(
        uint256 _milestoneId,
        uint projectId
    ) internal milestoneDoesNotExist(_milestoneId) {
        if (_milestoneId == 0)
            revert RevertWithError("Milestone ID cannot be 0");

        ProjectMilestone memory milestone = ProjectMilestone({
            milestoneId: _milestoneId,
            projectId: projects[projectId],
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            status: MilestoneStatus.InProgress
        });

        projectMilestones[_milestoneId] = milestone;

        emit NewMilestone(
            milestone.milestoneId,
            milestone.projectId,
            milestone.createdAt
        );
    }
}
