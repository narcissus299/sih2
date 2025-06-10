pragma solidity ^0.4.21;

import "./user.sol";

contract Task is User {

    // Events
    event TaskCreated(uint indexed taskId, uint indexed requesterId, uint reward);
    event TaskApplied(uint indexed taskId, uint indexed workerId);
    event WorkerConfirmed(uint indexed taskId, uint indexed workerId);
    event TaskClaimed(uint indexed taskId, uint indexed workerId);
    event TaskSubmitted(uint indexed taskId, uint indexed workerId);
    event TaskCompleted(uint indexed taskId, uint indexed workerId, uint reward);
    event TaskRejected(uint indexed taskId, uint indexed workerId);
    event TaskCancelled(uint indexed taskId);
    event FundsEscrowed(uint indexed taskId, uint amount);
    event FundsReleased(uint indexed taskId, uint amount, address recipient);
    
    struct Task {
        uint requesterId;
        uint32 taskDuration;
        uint expRequired;
        uint expAwarded;
        uint reward;
        uint postTime;
        bool isEscrowed;      // Flag to check if funds are escrowed
    }

    Task[] public tasks;

    mapping(uint => uint) internal applyForTask;
    mapping(uint => uint) internal taskAssignedTo;
    mapping(uint => uint) internal taskStatus;
    mapping(uint => uint) internal taskEscrow;  // Track escrowed funds for each task

    uint32 timeoutBegin;

    // Task Status Codes
    // Pending 1
    // Free 2
    // Unclaimed 3
    // Cancelled 4
    // Claimed 5
    // Submitted 6
    // Evaluated 7
    // Pending 8
    // Completed 9

    // Create a new task with payment
    function generateTask(uint _requesterId) public payable {
        require(msg.sender == requesterAddress[_requesterId], "Only requester can create tasks");
        
        // Ensure requester has enough funds
        require(msg.value > 0, "Must provide funds for task reward");
        
        // Create the task
        uint taskId = tasks.push(Task(
            _requesterId, 
            10 days, 
            100, 
            50, 
            msg.value, // Use actual ETH value as reward
            uint32(now),
            true       // Mark as escrowed
        )) - 1;
        
        // Set task status to pending
        taskStatus[taskId] = 1;
        
        // Escrow the funds
        taskEscrow[taskId] = msg.value;
        
        // Emit events
        emit TaskCreated(taskId, _requesterId, msg.value);
        emit FundsEscrowed(taskId, msg.value);
    }

    // Apply for a task
    function applyTask(uint taskId, uint _workerId) public {
        require(msg.sender == workerAddress[_workerId], "Only worker can apply");
        require(taskStatus[taskId] == 1, "Task must be pending");
        require(tasks[taskId].isEscrowed, "Task must have escrowed funds");
        
        if(workerStatus[_workerId] == 2 && (workers[_workerId].expPts >= tasks[taskId].expRequired)){
            applyForTask[_workerId] = taskId;
            emit TaskApplied(taskId, _workerId);
        }
    }

    // Requester confirms a worker for a task
    function workerConfirm(uint taskId, uint _requesterId, uint _workerId) public {
        require(msg.sender == requesterAddress[_requesterId], "Only requester can confirm");
        require(taskId == applyForTask[_workerId], "Worker must have applied");
        require(taskStatus[taskId] == 1, "Task must be pending");
        
        taskStatus[taskId] = 3; // Set to unclaimed
        timeoutBegin = uint32(now);
        
        emit WorkerConfirmed(taskId, _workerId);
    }

    // Worker claims a task
    function workerClaim(uint taskId, uint _workerId) public returns(bool) {
        require(msg.sender == workerAddress[_workerId], "Only worker can claim");
        require(taskStatus[taskId] == 3, "Task must be unclaimed");
        
        uint32 currentTime = uint32(now);
        if(currentTime > uint32(timeoutBegin + 1 days)) { // Changed to 1 day timeout
            taskStatus[taskId] = 4; // Cancelled
            emit TaskCancelled(taskId);
            return false;
        }

        taskAssignedTo[taskId] = _workerId;
        taskStatus[taskId] = 5; // Claimed
        
        emit TaskClaimed(taskId, _workerId);
        return true;
    }

    // Worker submits completed task
    function submitTask(uint taskId, uint _workerId) public {
        require(msg.sender == workerAddress[_workerId], "Only assigned worker can submit");
        require(taskStatus[taskId] == 5, "Task must be claimed");
        require(taskAssignedTo[taskId] == _workerId, "Only assigned worker can submit");
        
        taskStatus[taskId] = 6; // Submitted
        
        emit TaskSubmitted(taskId, _workerId);
    }

    // Internal function to reward worker with ETH and experience
    function rewardWorker(uint _workerId, uint taskId) internal {
        // Get task reward
        uint reward = tasks[taskId].reward;
        address workerAddr = workerAddress[_workerId];
        
        // Update worker's experience points
        workers[_workerId].expPts += uint32(tasks[taskId].expAwarded);
        
        // Transfer escrowed funds to worker
        if (taskEscrow[taskId] >= reward && reward > 0) {
            taskEscrow[taskId] = 0;
            ethBalances[workerAddr] += reward;
            
            emit FundsReleased(taskId, reward, workerAddr);
        }
        
        // Update task status
        taskStatus[taskId] = 9; // Completed
        workerStatus[_workerId] = 2; // Available for new tasks
    }

    // Requester accepts task submission and releases payment
    function acceptSubmission(uint _requesterId, uint taskId) public {
        require(msg.sender == requesterAddress[_requesterId], "Only requester can accept");
        require(taskStatus[taskId] == 6, "Task must be submitted");
        require(tasks[taskId].requesterId == _requesterId, "Only task requester can accept");
        
        uint workerId = taskAssignedTo[taskId];
        
        taskStatus[taskId] = 7; // Evaluated
        rewardWorker(workerId, taskId);
        
        emit TaskCompleted(taskId, workerId, tasks[taskId].reward);
    }

    // Requester rejects task submission
    function rejectSubmission(uint _requesterId, uint taskId) public {
        require(msg.sender == requesterAddress[_requesterId], "Only requester can reject");
        require(taskStatus[taskId] == 6, "Task must be submitted");
        require(tasks[taskId].requesterId == _requesterId, "Only task requester can reject");
        
        uint workerId = taskAssignedTo[taskId];
        taskStatus[taskId] = 1; // Back to pending
        
        emit TaskRejected(taskId, workerId);
    }
    
    // Function to refund escrowed funds if task is cancelled
    function refundTaskPayment(uint _requesterId, uint taskId) public {
        require(msg.sender == requesterAddress[_requesterId], "Only requester can refund");
        require(tasks[taskId].requesterId == _requesterId, "Only task requester can refund");
        require(taskStatus[taskId] == 4, "Task must be cancelled");
        require(taskEscrow[taskId] > 0, "No funds to refund");
        
        uint refundAmount = taskEscrow[taskId];
        address requesterAddr = requesterAddress[_requesterId];
        
        // Transfer escrowed funds back to requester
        taskEscrow[taskId] = 0;
        ethBalances[requesterAddr] += refundAmount;
        
        emit FundsReleased(taskId, refundAmount, requesterAddr);
    }

    // Get list of pending tasks
    function displayPendingTasks() public view returns(uint[]) {
        uint[] memory pendingTasks = new uint[](tasks.length); // Pre-allocate max possible size
        uint count = 0;
        
        for(uint i=0; i < tasks.length; i++) {
            if(taskStatus[i] == 1) {
                pendingTasks[count] = i;
                count++;
            }
        }
        
        // Create properly sized array with just the pending tasks
        uint[] memory result = new uint[](count);
        for(uint j=0; j < count; j++) {
            result[j] = pendingTasks[j];
        }
        
        return result;
    }
    
    // Function to cancel a pending task and refund payment
    function cancelTask(uint taskId, uint _requesterId) public {
        require(msg.sender == requesterAddress[_requesterId], "Only requester can cancel");
        require(tasks[taskId].requesterId == _requesterId, "Only task requester can cancel");
        require(taskStatus[taskId] == 1, "Task must be pending");
        
        taskStatus[taskId] = 4; // Cancelled
        
        // Auto-refund the escrowed payment
        if (taskEscrow[taskId] > 0) {
            uint refundAmount = taskEscrow[taskId];
            address requesterAddr = requesterAddress[_requesterId];
            
            taskEscrow[taskId] = 0;
            ethBalances[requesterAddr] += refundAmount;
            
            emit FundsReleased(taskId, refundAmount, requesterAddr);
        }
        
        emit TaskCancelled(taskId);
    }
    
    // Function to reactivate a cancelled task with payment
    function reactivateTask(uint taskId, uint _requesterId) public payable {
        require(msg.sender == requesterAddress[_requesterId], "Only requester can reactivate");
        require(tasks[taskId].requesterId == _requesterId, "Only task requester can reactivate");
        require(taskStatus[taskId] == 4, "Task must be cancelled");
        require(msg.value > 0, "Must provide funds for task reward");
        
        // Update task status and escrow funds
        taskStatus[taskId] = 1; // Pending
        taskEscrow[taskId] = msg.value;
        tasks[taskId].reward = msg.value;
        tasks[taskId].isEscrowed = true;
        
        emit TaskCreated(taskId, _requesterId, msg.value);
        emit FundsEscrowed(taskId, msg.value);
    }
}
