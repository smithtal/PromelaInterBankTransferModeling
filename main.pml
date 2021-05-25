#define true 1
#define false 0

#define PROC_CHASE 0
#define PROC_CITI 1
#define PROC_CENTRAL 2

#define MAX_BANK 3
#define MAX_PROCESS 6

#define MSG_NULL 0
#define MSG_DEBIT 1
#define MSG_ACCEPT 2
#define MSG_DECLINE 3
#define MSG_TRANSFER 4
#define MSG_CREDIT 5
#define MSG_FINISHED 6
#define MSG_RECEIVED 7


// msgtype, msgfrom, sender, fund
chan Proc[MAX_PROCESS] = [20] of {byte, byte, byte, int};

typedef Customer {
    int balance = 500;
    int bank;
    int receiver;
};

Customer customers[MAX_PROCESS - MAX_BANK];
int chase_bal = 0;
int citi_bal = 0;
int fund = 200;
bool complete[MAX_PROCESS - MAX_BANK];

proctype BankType(int num){
    int temp;
    int i;
    for (i : 0 .. num - 1){
        select(temp: 0 .. 1);
        customers[i].bank = temp;
    }
}

proctype Transaction(byte current_p) {
    byte msgtype, msgfrom, sender;
    int msgdata;
    int i;

    printf("current proc is %d\n", current_p);

    msgtype = MSG_NULL;

    do
    // if current process is user, randomly pick a process as the receiver 
    :: (current_p > MAX_BANK - 1) ->
        // start user process
        int j;
        do
        :: select(j: MAX_PROCESS - MAX_BANK + 1 .. MAX_PROCESS - 1);
        :: (j != current_p && j > MAX_BANK - 1) -> 
            customers[current_p - MAX_BANK].receiver = j;
            break;
        od;
        //printf("receiver is %d\n", j);

        // bank of current process receives msg to debit current p the fund
        int k = customers[current_p - MAX_BANK].bank;
        Proc[k] ! MSG_DEBIT(current_p, current_p, fund);
        printf("Proc %d is trying to send $%d at %d to Proc %d at %d\n", 
            current_p, fund, customers[current_p - MAX_BANK].bank, j, customers[j - MAX_BANK].bank);

        do
        :: Proc[current_p] ? msgtype(msgfrom, sender, msgdata) ->
            // check if current user process received any message
            if
            :: (msgtype == MSG_ACCEPT) ->
                if
                :: (msgfrom == 0) ->
                    printf("Chase Bank debited $%d from account %d\n", msgdata, current_p);
                :: (msgfrom == 1) ->
                    printf("Citi Bank debited $%d from account %d\n", msgdata, current_p);
                fi;

            :: (msgtype == MSG_DECLINE) ->
                if
                :: (msgfrom == 0) ->
                    printf("Chase Bank declined the transfer of $%d from account %d\n", msgdata, current_p);
                :: (msgfrom == 1) ->
                    printf("Citi Bank declined the transfer of $%d from account %d\n", msgdata, current_p);
                fi;
            
            // receiver check if fund is received
            :: (msgtype == MSG_FINISHED) ->
                Proc[msgfrom] ! MSG_RECEIVED(current_p, sender, msgdata);
                complete[sender - MAX_BANK] = true; 
                printf("Proc %d successfully send $%d to Proc %d, current balance of Proc %d is $%d\n", 
                    sender, msgdata, current_p, current_p, customers[current_p - MAX_BANK].balance);
            fi;

            msgtype = MSG_NULL;
        :: (msgtype == MSG_NULL) -> skip;
        od;

    :: (current_p < MAX_BANK) ->
    // start bank process
        // check if received any message
        do
        :: Proc[current_p] ? msgtype(msgfrom, sender, msgdata) -> break;
        :: (msgtype == MSG_NULL) -> skip;
        od;

        // received a message
        if
        :: (msgtype == MSG_DEBIT) ->
            // check msgfrom user process has enough money for debit
            //fund = msgdata;
            printf("DEBIT PROCESS: Proc %d has balance of $%d\n", 
                msgfrom, customers[msgfrom - MAX_BANK].balance);
            if
            :: (customers[msgfrom - MAX_BANK].balance >= msgdata) ->
                // debit fund from sender's account
                customers[msgfrom - MAX_BANK].balance = customers[msgfrom - MAX_BANK].balance - msgdata;
                int receiver = customers[msgfrom - MAX_BANK].receiver;

                Proc[msgfrom] ! MSG_ACCEPT(current_p, sender, msgdata); // send accept msg to sender

                if
                // if same bank
                :: (customers[msgfrom - MAX_BANK].bank == customers[receiver - MAX_BANK].bank) ->
                    customers[receiver - MAX_BANK].balance = customers[receiver - MAX_BANK].balance + msgdata;
                    Proc[receiver] ! MSG_FINISHED(current_p, sender, msgdata);
                    printf("$%d is transferred from Proc %d to Proc %d at %d\n",
                        msgdata, msgfrom, receiver, customers[msgfrom - MAX_BANK].bank);

                // if different bank, go through central bank proc
                :: (customers[msgfrom - MAX_BANK].bank != customers[receiver - MAX_BANK].bank) ->
                    if
                    // if chase, add fund to chase's account in central bank
                    :: (customers[msgfrom - MAX_BANK].bank == 0) ->
                        chase_bal = chase_bal + msgdata;
                        printf("Proc %d to Proc %d: $%d is added to chase account\n",
                            msgfrom, receiver, msgdata);

                    // see above for citi
                    :: (customers[msgfrom - MAX_BANK].bank == 1) ->
                        citi_bal = citi_bal + msgdata;
                        printf("Proc %d to Proc %d: $%d is added to citi account\n",
                            msgfrom, receiver, msgdata);
                    fi;
                    Proc[PROC_CENTRAL] ! MSG_TRANSFER(msgfrom, msgfrom, msgdata); // send transfer msg to central bank
                fi;

            :: (customers[msgfrom - MAX_BANK].balance < msgdata) ->
                Proc[msgfrom] ! MSG_DECLINE(current_p, msgfrom, msgdata);
                printf("Not enough money in Proc %d's account\n", msgfrom);
            fi;
            
            msgtype = MSG_NULL;

        :: (msgtype == MSG_TRANSFER) ->
            if
            :: (customers[msgfrom - MAX_BANK].bank == 0) ->
                chase_bal = chase_bal - msgdata;
                citi_bal = citi_bal + msgdata;
                Proc[PROC_CITI] ! MSG_CREDIT(customers[msgfrom - MAX_BANK].receiver, sender, msgdata);
                printf("Proc %d to Proc %d: $%d is transferred from chase to citi\n",
                    msgfrom, customers[msgfrom - MAX_BANK].receiver, msgdata);

            :: (customers[msgfrom - MAX_BANK].bank == 1) ->
                citi_bal = citi_bal - msgdata;
                chase_bal = chase_bal + msgdata;
                Proc[PROC_CHASE] ! MSG_CREDIT(customers[msgfrom - MAX_BANK].receiver, sender, msgdata);
                printf("Proc %d to Proc %d: $%d is transferred from citi to chase\n",
                    msgfrom, customers[msgfrom - MAX_BANK].receiver, msgdata);
            fi;

            msgtype = MSG_NULL;

        :: (msgtype == MSG_CREDIT) ->
            // withdraw money from central bank
            if
            :: (current_p == 0) ->
                chase_bal = chase_bal - msgdata;
                customers[msgfrom - MAX_BANK].balance = customers[msgfrom - MAX_BANK].balance + msgdata;
                Proc[msgfrom] ! MSG_FINISHED(current_p, sender, msgdata);
                printf("chase withdraw money and credit Proc %d $%d\n", msgfrom, msgdata);

            :: (current_p == 1) ->
                citi_bal = citi_bal - msgdata;
                customers[msgfrom - MAX_BANK].balance = customers[msgfrom - MAX_BANK].balance + msgdata;
                Proc[msgfrom] ! MSG_FINISHED(current_p, sender, msgdata);
                printf("citi withdraw money and credit Proc %d $%d\n", msgfrom, msgdata);
            fi;

            msgtype = MSG_NULL;

        :: (msgtype == MSG_RECEIVED) ->
            i = 0;
            int h;
            do
            :: (i < MAX_PROCESS - MAX_BANK) ->
                if
                :: (complete[i] == false) -> break;
                :: else -> i++;
                fi;
            :: (i == MAX_PROCESS - MAX_BANK) -> break;
            od;

            msgtype = MSG_NULL;
        fi;
    od;
}

init{
    int p;
    p = MAX_PROCESS - 1;
    run BankType(MAX_PROCESS - MAX_BANK);
    do
    :: (p >= 0) -> 
        /* run BankType(MAX_PROCESS - MAX_BANK); */
        run Transaction(p); 
        p = p - 1;
    :: (p < 0) -> break;
    od;
}