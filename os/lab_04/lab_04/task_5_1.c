#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>

#define N 2 //children count
#define MAX_LEN 30

int f = 0;
void sig_handler(int signal)
{
    f = 1;
    printf("Catch signal: %d\n", signal);
}

int main(void)
{
    int waiting_signal_time = 4;
    printf("Parent PID: %d, Parent group ID: %d\n", getpid(), getpgrp());

    const char *messages[N] = {"aaaaa", "BBBBBBBBBBBBB"};

    signal(SIGINT, sig_handler);
    printf("Enter ctrl + c to show messages\n");
    sleep(waiting_signal_time);

    int fd[2];
    if (pipe(fd) == -1)
    {
        perror("pipe error");
        exit(3);
    }

    for (int i = 0; i < N; i++)
    {
        pid_t child_pid = fork();
        if (child_pid == -1)
        {
            perror("Can't fork");
            exit(1);
        }
        else if (child_pid == 0)
        {
            printf("Child process №%d pid: %d, ppid: %d, group ID: %d\n", i, getpid(), getppid(), getpgrp());

            
            if (f)
            {
            	close(fd[0]);
            	write(fd[1], messages[i], strlen(messages[i]));
            }

            printf("Child process №%d died\n", i);

            exit(EXIT_SUCCESS);    
        }
        else
        {
            printf("Parent process have child №%d pid: %d\n", i, child_pid);
        }
    }

    for (int i = 0; i < N; i++)
    {
        int status;
        pid_t childpid = wait(&status);

        if (WIFEXITED(status))
            printf("Child process %d has been finished correctly with exit code %d\n", childpid, WEXITSTATUS(status));
        else if (WIFSIGNALED(status))
            printf("Child process %d has been finished by signal %d\n", childpid, WTERMSIG(status));
        else if (WIFSTOPPED(status))
            printf("Child process %d has been stopped by signal %d\n", childpid, WSTOPSIG(status));
    }

    close(fd[1]);
    char fmsg[MAX_LEN] = "";
    char smsg[MAX_LEN] = "";
    char tmsg[MAX_LEN] = "";
    
    
    read(fd[0], fmsg, strlen(messages[0]));
    printf("Received message: %s\n", fmsg);
    read(fd[0], smsg, strlen(messages[1]));
    printf("Received message: %s\n", smsg);
    read(fd[0], tmsg, MAX_LEN);
    printf("Received message: %s\n", tmsg);
    close(fd[0]);
    
    puts("Parent process died");
    exit(EXIT_SUCCESS);
}
