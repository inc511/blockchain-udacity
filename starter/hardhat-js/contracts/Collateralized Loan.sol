// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CollateralizedLoan {
    // Define the structure of a loan
    struct Loan {
        address borrower;          // Address of the borrower
        address lender;            // Address of the lender
        uint collateralAmount;    // Amount of collateral deposited by the borrower
        uint loanAmount;          // Amount of loan requested by the borrower
        uint interestRate;        // Interest rate on the loan
        uint dueDate;             // Due date for the loan repayment (timestamp)
        bool isFunded;            // Flag to check if the loan is funded
        bool isRepaid;            // Flag to check if the loan is repaid
    }

    // Create a mapping to manage loans by their ID
    mapping(uint => Loan) public loans;
    uint public nextLoanId; // ID to keep track of the next loan to be created

    // Define events for loan requests, funding, repayment, and collateral claims
    event LoanRequested(uint loanId, address borrower, uint collateralAmount, uint loanAmount, uint interestRate, uint dueDate);
    event LoanFunded(uint loanId, address lender);
    event LoanRepaid(uint loanId);
    event CollateralClaimed(uint loanId);

    // Modifier to check if a loan exists
    modifier loanExists(uint _loanId) {
        require(_loanId < nextLoanId, "Loan does not exist");
        _;
    }

    // Modifier to check if a loan is not yet funded
    modifier notFunded(uint _loanId) {
        require(!loans[_loanId].isFunded, "Loan is already funded");
        _;
    }

    // Function to deposit collateral and request a loan
    function depositCollateralAndRequestLoan(uint _interestRate, uint _duration) external payable {
        require(msg.value > 0, "Collateral amount must be more than 0");

        uint loanAmount = msg.value; // Loan amount is equal to the collateral amount
        uint loanId = nextLoanId++; // Generate new loan ID and increment for next loan

        // Create a new loan entry in the loans mapping
        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0), // Initially, no lender
            collateralAmount: msg.value,
            loanAmount: loanAmount,
            interestRate: _interestRate,
            dueDate: block.timestamp + _duration,
            isFunded: false,
            isRepaid: false
        });

        // Emit an event for the loan request
        emit LoanRequested(loanId, msg.sender, msg.value, loanAmount, _interestRate, block.timestamp + _duration);
    }

    // Function to fund a loan by a lender
    function fundLoan(uint _loanId) external payable loanExists(_loanId) notFunded(_loanId) {
        Loan storage loan = loans[_loanId];
        require(msg.value == loan.loanAmount, "Incorrect loan amount");

        loan.lender = msg.sender; // Set the lender of the loan
        loan.isFunded = true; // Mark the loan as funded

        // Transfer the loan amount to the borrower
        payable(loan.borrower).transfer(msg.value);

        // Emit an event for the loan funding
        emit LoanFunded(_loanId, msg.sender);
    }

    // Function to repay the loan by the borrower
    function repayLoan(uint _loanId) external payable loanExists(_loanId) {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.borrower, "Only the borrower can repay the loan");
        require(loan.isFunded, "Loan is not funded");
        require(!loan.isRepaid, "Loan is already repaid");

        // Calculate the repayment amount including interest
        uint repaymentAmount = loan.loanAmount + (loan.loanAmount * loan.interestRate / 100);
        require(msg.value == repaymentAmount, "Incorrect repayment amount");

        loan.isRepaid = true; // Mark the loan as repaid

        // Transfer repayment amount to the lender and collateral back to the borrower
        payable(loan.lender).transfer(msg.value);
        payable(loan.borrower).transfer(loan.collateralAmount);

        // Emit an event for the loan repayment
        emit LoanRepaid(_loanId);
    }

    // Function to claim collateral by the lender if the loan is overdue
    function claimCollateral(uint _loanId) external loanExists(_loanId) {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.lender, "Only the lender can claim collateral");
        require(loan.isFunded, "Loan is not funded");
        require(!loan.isRepaid, "Loan is already repaid");
        require(block.timestamp > loan.dueDate, "Loan is not yet due");

        // Transfer the collateral to the lender
        payable(loan.lender).transfer(loan.collateralAmount);

        // Emit an event for collateral claimed
        emit CollateralClaimed(_loanId);
    }
}
