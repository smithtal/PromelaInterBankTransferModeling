#define true 1
#define false 0

#define PROC_USER 0
#define PROC_STORE1 1
#define PROC_STORE2 2
#define PROC_STORE3 3

#define MAX_STORE 3
#define MAX_PROCESS 4

#define MSG_NULL 0
#define MSG_CHARGE 1
#define MSG_CHECK 2
#define MSG_REPORT 3
#define MSG_DECLINE 4
#define MSG_ACCEPT 5

#define CREDIT_LIMIT 1000

chan Pin[MAX_PROCESS] = [10] of {byte, byte, int};

proctype P(byte my_id) {
    byte msgtype, msgfrom;
    int msgdata;
    int i;

    if
    :: (my_id != PROC_USER) ->
        int balance = 0;
        int other_bal = 0; //balance of other stores
        int charge = 0;
        bool checking = false;
        bool complete[MAX_STORE];
    :: else -> skip;
    fi;

    msgtype = MSG_NULL;

    do
    :: (my_id == PROC_USER) ->
        // start user process
        Pin[PROC_STORE1]!MSG_CHARGE(my_id, 500);
        Pin[PROC_STORE2]!MSG_CHARGE(my_id, 500);
        Pin[PROC_STORE3]!MSG_CHARGE(my_id, 500);

        do
        :: Pin[my_id]?msgtype(msgfrom, msgdata) ->
            // received a message
            if
            :: (msgtype == MSG_ACCEPT) ->
                printf("Store %d accepted the charge of %d\n", msgfrom, msgdata);
            :: (msgtype == MSG_DECLINE) ->
                printf("Store %d declined the charge of %d\n", msgfrom, msgdata);
            fi;
            msgtype = MSG_NULL;
        :: (msgtype == MSG_NULL) -> skip;
        od;

    :: (my_id != PROC_USER) ->
    // start store process
        // scan to receive a message
        do
        :: Pin[my_id]?msgtype(msgfrom, msgdata) -> break;
        :: (msgtype == MSG_NULL) -> skip;
        od;

        // received a message
        if
        :: (msgtype == MSG_CHARGE) ->
            if
            :: (checking == true) ->
                // checking with other stores is in process, loop back charge message
                Pin[my_id]!msgtype(msgfrom, msgdata);

            :: (checking == false) ->
                charge = msgdata;
                if
                :: (charge > CREDIT_LIMIT - balance) ->
                    Pin[PROC_USER]!MSG_DECLINE(my_id, charge);
                :: else ->
                    // start checking process
                    checking = true;
                    other_bal = 0;
                    i = 1;
                    do
                    :: (i <= MAX_STORE) ->
                        if
                        :: (i != my_id) -> Pin[i]!MSG_CHECK(my_id, charge); complete[i - 1] = false;
                        :: else -> skip;
                        fi;
                        i++;
                    :: (i > MAX_STORE) -> break;
                    od;
                    complete[my_id - 1] = true;
                fi;
            fi;
            msgtype = MSG_NULL;

        :: (msgtype == MSG_CHECK) ->
            if
            :: (checking == false) -> Pin[msgfrom]!MSG_REPORT(my_id, balance);
            :: ((checking == true) && (my_id >msgfrom)) -> Pin[msgfrom]!MSG_REPORT(my_id, balance);
            :: ((checking == true) && (my_id < msgfrom)) -> 
                // wait for other stores' response, loop back check message
                Pin[my_id]!MSG_CHECK(msgfrom, msgdata);
            fi;
            msgtype = MSG_NULL;

        :: (msgtype == MSG_REPORT) ->
            complete[msgfrom - 1] = true;
            other_bal = other_bal + msgdata;
            i = 0;
            do
            :: (i<MAX_STORE) ->
                if
                :: (complete[i] == false) -> break;
                :: else -> i++;
                fi;
            :: (i == MAX_STORE) -> break;
            od;
            
            if
            :: (i == MAX_STORE) ->
                // report complete
                checking = false;
                if
                :: (charge <= (CREDIT_LIMIT - balance - other_bal)) ->
                    // charge accepted
                    balance = balance + charge;
                    Pin[PROC_USER]!MSG_ACCEPT(my_id, charge);
                :: else ->
                    // charge declined
                    Pin[PROC_USER]!MSG_DECLINE(my_id, charge);
                fi;
                charge = 0;
            :: else -> skip //continue waiting report
            fi;
            msgtype = MSG_NULL;
        fi;
    od;
}

init{
    int p;
    p = MAX_PROCESS - 1;
    do
    :: (p >= 0) -> run P(p); p = p - 1;
    :: (p < 0) -> break;
    od;
}