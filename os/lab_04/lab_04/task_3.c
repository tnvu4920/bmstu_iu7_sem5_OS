#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

int main() 
{
	// Child 1
	pid_t child1 = fork();
	if (child1 == -1)
	{
		perror("Child 1: Couldn't fork.");
		exit(1);
 	}
	else if (child1 == 0)
	{
		printf("Child 1: pid = %d, ppid = %d, groupid = %d\n", getpid(), getppid(), getpgrp());
		if (execlp("ps", "ps", "al", 0) == -1)
 		{
			perror("Child 1: couldn't exec.");
			exit(1);
		}
	}
	
	// Child 2
	pid_t child2 = fork();
	if (child2 == -1)
	{
		perror("Child 2: Couldn't fork.");
		exit(1);
	}
	else if (child2 == 0)	
	{
		printf("Child 2: pid = %d, ppid = %d, groupid = %d\n", getpid(), getppid(), getpgrp());
		if (execlp("ls", "ls", "-ail", 0) == -1)
		{
			perror("Child 2: couldn't exec.");
			exit(1);
		}
	}

	// Parent
	if (child1 != 0 && child2 != 0)
	{
		int status1, status2;
		pid_t ret1 = wait(&status1);
		pid_t ret2 = wait(&status2);
		
		printf("Parent: pid=%d, groupid=%d, child1=%d, child2=%d\n", getpid(), getpgrp(), child1, child2);

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
	}

	return 0;
}
