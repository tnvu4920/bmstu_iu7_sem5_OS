#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <signal.h>

#define REP_N 2 // loop rep time
#define SLP_T 2 // sleep time
#define BUF_SIZE (sizeof(char) * 256)
#define GET 1

enum error_code {
    ok,
    pipe_error,
    exec_error,
    fork_error,
    error
};

int mode = 0;

void sigint_catcher(int signum) {
    printf( "\nProccess Catched signal #%d\n", signum);
    printf("Sent any message to clihd!\n");
    mode = GET;
}
int main()
{
    int child[REP_N], fd[REP_N];
    char buffer[BUF_SIZE] = { 0 };
    char *const msg[REP_N] = {"1st msg\n", "2nd msg long\n"};
    int pid;

    if (REP_N < 2) {
        perror("at most needs to create two childs!");
        return error;
    }

    if (pipe(fd) == -1) {
        perror("can't pipe!");
        return pipe_error;
    }

    printf("Parent process PID = %d, Group: %d\n", getpid(), getpgrp());
    printf("Waiting for CTRL+C signal.\n");
    signal(SIGINT, sigint_catcher);
    sleep(3);

    for (size_t i = 0; i < REP_N; i++) {
        pid = fork();

        if (pid == -1) {
            perror("Fork failed!");
            return fork_error;
        } else if (!pid) {
            signal(SIGINT, sigint_catcher);

            if (mode) {
                close(fd[0]);
                write(fd[1], msg[i], strlen(msg[i]));
                printf("msg №%zu sent from child to parent!\n", i + 1);
            } else {
                printf("No signal sent!\n");
            }

            return ok;
        } else {
            child[i] = pid;
        }
    }

    puts("msg from parent process");
    
    for (size_t i = 0; i < REP_N; i++) {
        int status, ret_val = 0;
        
        pid_t child_pid = wait(&status);

        printf("\nChild process PID = %d, completed, status %d\n", \
                                    child_pid, status);
        
        if (WIFEXITED(ret_val)) {
            printf("Child process [№ = %zu] completed with %d exit code\n", 
                                        i + 1, WEXITSTATUS(ret_val));
        } else if (WIFSIGNALED(ret_val)) {
            printf("Child process [№ = %zu] completed with %d exit code\n", 
                                        i + 1, WTERMSIG(ret_val));
        } else if (WIFSTOPPED(ret_val)) {
            printf("Child process [№ = %zu] completed with %d exit code\n", 
                                        i + 1, WSTOPSIG(ret_val));
        }
    }
    
    close(fd[1]);
    read(fd[0], buffer, BUF_SIZE);
    printf("Received msg: \n%s\n", buffer);

    puts("msg from parent process");
    
    for (size_t i = 0; i < REP_N; i++)
        printf("child[%zu].pid = %d\n", i, child[i]);
    
    return ok;
}