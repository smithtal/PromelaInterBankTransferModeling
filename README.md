# Modeling Inter-Bank transfers through a third-party bank with PROMELA.

## PROMELA

PROMELA (Process Meta Language) is a language used to model and verify the correctness of concurrent and distributed systems and algorithms.

This project aims to model the process of transfering funds between two banks through a third party.

## Model

This project treats the transfer process as a concurrent distributed system. It seeks to account for many of the pitfalls that occur in such systems such as:

- Lossy networks
- Delayed responses
- Consistency
- Failure

## Running this project

This project requires the use of the [Spin](http://spinroot.com/spin/whatispin.html) software verification tool. Installation instructions can be found in the [official documentation](http://spinroot.com/spin/Man/README.html).

To execute a sample of the simulation run the command `spin transfer.pml`
