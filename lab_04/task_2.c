#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define DELAY 5

int main()
{
	//Fork Child 1
	pid_t child1 = fork();
	if (child1 == -1)
	{
		perror("Couldn't fork.");
		exit(1);
	}
	else if (child1 == 0)
	{
		printf("Child 1: pid = %d, ppid = %d, groupid = %d\n", getpid(), getppid(), getpgrp());
		sleep(DELAY);
		printf("Child 1: Exiting\n");
		return 0;
	}

	//Fork Child 2
	pid_t child2 = fork();
	if (child2 == -1)
	{
		perror("Couldn't fork.");
		exit(1);
	}
	else if (child2 == 0)
	{
		printf("Child 2: pid = %d, ppid = %d, groupid = %d\n", getpid(), getppid(), getpgrp());
                sleep(DELAY);
                printf("Child 2: Exiting\n");
                return 0;
	}
	
	//Parent
	int status1;
	pid_t ret1 = wait(&status1);
	int status2;
	pid_t ret2 = wait(&status2);

	printf("Parent: pid = %d, group = %d, Child1 = %d, Child2 = %d\n", getpid(), getpgrp(), child1, child2);

	if (WIFEXITED(status1))
		printf("Parent: child %d finished with %d code.\n", ret1, WEXITSTATUS(status1));
	else if (WIFSIGNALED(status1))
		printf("Parent: child %d finished from signal with %d code.\n", ret1, WTERMSIG(status1));
	else if (WIFSTOPPED(status1))
		printf("Parent: child %d finished from signal with %d code.\n", ret1, WSTOPSIG(status1));

	if (WIFEXITED(status2))
		printf("Parent: child %d finished with %d code.\n", ret2, WEXITSTATUS(status2));
	else if (WIFSIGNALED(status2))
		printf("Parent: child %d finished from signal with %d code.\n", ret2, WTERMSIG(status2));
	else if (WIFSTOPPED(status2))
		printf("Parent: child %d finished from signal with %d code.\n", ret2, WSTOPSIG(status2));
	
	return 0;
}
