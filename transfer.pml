chan bankOfAmericaCustomer = [1] of { int }

proctype Alice(){
    bankOfAmericaCustomer ! 100;
    printf("Alice: Send $100.00 to Bob\n");
}

proctype BankOfAmerica(){
    int alicesBalance = 2000;
    int debitAmout;
    do
    :: bankOfAmericaCustomer ? debitAmout ->
        printf("Bank of America: Received Alices' request.\n");
        printf("Bank of America: Alices' current balance is %d \n.", alicesBalance);
        alicesBalance = alicesBalance - debitAmout;
        printf("Bank of America: Alices new balance is %d \n.", alicesBalance);
    od
}


init {
    run Alice();
    run BankOfAmerica();
}