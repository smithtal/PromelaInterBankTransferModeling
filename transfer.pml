mtype {CREDIT, DEBIT, TRANSFER};

chan bankOfAmericaCustomer = [2] of { mtype, int };
chan bankOfAmericaCentralBank = [2] of {mtype, int };
chan wellsFargoCentralBank = [2] of { mtype, int };
chan interBank = [2] of { mtype, int };

proctype Alice(){
    bankOfAmericaCustomer ! TRANSFER, 100;
    printf("Alice: Send $100.00 to Bob\n");
}

proctype BankOfAmerica(){
    int alicesBalance = 2000;
    int transferAmount;
    do
    :: bankOfAmericaCustomer ? TRANSFER, transferAmount ->
        printf("Bank of America: Received Alices' request.\n");
        printf("Bank of America: Alices' current balance is %d \n.", alicesBalance);
        alicesBalance = alicesBalance - transferAmount;
        printf("Bank of America: Alices new balance is %d \n.", alicesBalance);
        bankOfAmericaCentralBank ! CREDIT, transferAmount; 
        interBank ! CREDIT, transferAmount;
    od
}

proctype CentralBank(){
    int bankOfAmericaBalance = 0;
    int wellsFargoBalance = 0;
    int creditAmount;
    int debitAmount;

    do 
    :: bankOfAmericaCentralBank ? CREDIT(creditAmount) -> 
        printf("Central Bank: Bank of America is crediting WellsFargo %d\n", creditAmount);
        printf("Central Bank: WellsFargo original balance: %d\n", wellsFargoBalance);
        wellsFargoBalance = wellsFargoBalance + creditAmount;
        printf("Central Bank: WellsFargo new balance: %d\n", wellsFargoBalance);
    
    :: wellsFargoCentralBank ? DEBIT(debitAmount) ->
        printf("Central Bank: Wells Fargo its account for %d\n", debitAmount);
        printf("Central Bank: Wells Fargo original balance: %d\n", wellsFargoBalance);
        wellsFargoBalance = wellsFargoBalance - debitAmount;
        printf("Central Bank: WellsFargo new balance: %d\n", wellsFargoBalance);
    od
}

proctype WellsFargo(){
    int bobsBalance = 0;
    int creditAmount = 0;
    do
    :: interBank ? CREDIT(creditAmount) -> 
        printf("WellsFargo: Bank of America wants to Credit Bob's account.\n");
        printf("WellsFargo: Bob's original balance %d.\n", bobsBalance);
        wellsFargoCentralBank ! DEBIT, creditAmount;
        bobsBalance = bobsBalance + creditAmount;
        printf("WellsFargo: Bob's new balance: %d\n", bobsBalance);
    od

}

init {
    run Alice();
    run BankOfAmerica();
    run CentralBank();
    run WellsFargo();
}