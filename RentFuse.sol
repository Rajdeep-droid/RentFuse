// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract RentFuse {
    address public landlord;
    address public tenant;

    uint256 public rentAmount;
    uint256 public securityDeposit;
    uint256 public leaseStart;
    uint256 public leaseEnd;
    uint256 public rentDueDate;
    uint256 public lateFee;
    bool public leaseActive;
    bool public depositPaid;

    enum LeaseStatus { Created, Active, Terminated }
    LeaseStatus public status;

    event LeaseCreated(address landlord, address tenant);
    event RentPaid(address tenant, uint256 amount, uint256 timestamp);
    event LeaseTerminated(address by);
    event DepositRefunded(address to, uint256 amount);

    modifier onlyLandlord() {
        require(msg.sender == landlord, "Only landlord can call this");
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Only tenant can call this");
        _;
    }

    constructor(
        address _tenant,
        uint256 _rentAmount,
        uint256 _securityDeposit,
        uint256 _leaseDurationInDays,
        uint256 _lateFee
    ) {
        landlord = msg.sender;
        tenant = _tenant;
        rentAmount = _rentAmount;
        securityDeposit = _securityDeposit;
        leaseStart = block.timestamp;
        leaseEnd = block.timestamp + (_leaseDurationInDays * 1 days);
        rentDueDate = leaseStart + 30 days; // first due in 30 days
        lateFee = _lateFee;
        status = LeaseStatus.Created;
    }

    function activateLease() external payable onlyTenant {
        require(status == LeaseStatus.Created, "Lease already active");
        require(msg.value == securityDeposit, "Incorrect security deposit");
        depositPaid = true;
        leaseActive = true;
        status = LeaseStatus.Active;
        emit LeaseCreated(landlord, tenant);
    }

    function payRent() external payable onlyTenant {
        require(leaseActive, "Lease not active");
        require(block.timestamp <= leaseEnd, "Lease has ended");

        uint256 amountDue = rentAmount;

        if (block.timestamp > rentDueDate) {
            amountDue += lateFee;
        }

        require(msg.value == amountDue, "Incorrect rent payment");

        payable(landlord).transfer(msg.value);
        rentDueDate += 30 days; // Next month's rent
        emit RentPaid(msg.sender, msg.value, block.timestamp);
    }

    function terminateLease() external {
        require(
            msg.sender == landlord || msg.sender == tenant,
            "Only landlord or tenant can terminate"
        );
        require(leaseActive, "Lease already terminated");

        leaseActive = false;
        status = LeaseStatus.Terminated;
        emit LeaseTerminated(msg.sender);
    }

    function refundDeposit() external onlyLandlord {
        require(!leaseActive, "Lease still active");
        require(depositPaid, "No deposit paid");

        depositPaid = false;
        payable(tenant).transfer(securityDeposit);
        emit DepositRefunded(tenant, securityDeposit);
    }

    function getLeaseDetails() external view returns (
        address _landlord,
        address _tenant,
        uint256 _rentAmount,
        uint256 _leaseEnd,
        uint256 _nextDue,
        LeaseStatus _status
    ) {
        return (
            landlord,
            tenant,
            rentAmount,
            leaseEnd,
            rentDueDate,
            status
        );
    }
}
