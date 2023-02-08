#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include <sys/wait.h>

#define LEN 100
#define DELAY 2

int p_flag = 0;

void catch_sig(int signum) 
{
	printf("Proccess %d: catched signal %d\n", getpid(), signum);
	p_flag = 1;
}

int main() 
{
	//Pipe
	int fd[2];
	
	if (pipe(fd) == -1)
	{
		perror("Couldn't pipe.");
		exit(1);
	}
	
	// Ctrl + Z
	signal(SIGTSTP, catch_sig);
	sleep(1);

	// Child 1
	pid_t child1 = fork();

	if (child1 == -1)
	{
		perror("Couldn't fork.");
		exit(1);
	}
	
	else if (child1 == 0)
	{
		while (!p_flag);
		close(fd[0]);
		char msg1[] = "Hello From Child 1 ";
		write(fd[1], msg1, LEN);
		printf("Child 1: writen [%s] to Pipe\n", msg1);
	}

	// Child 2
	pid_t child2 = fork();

	if (child2 == -1)
	{
		perror("Couldn't fork.");
		exit(1);
	}	
	
	else if (child2 == 0)
	{
		while (!p_flag);
		close(fd[0]);
		char msg2[] = "Hello From Child 2 ";
		write(fd[1], msg2, LEN);
		printf("Child 2: writen [%s] to Pipe\n", msg2);
	}

	// Parent
	
	if (child1 != 0 && child2 != 0)
	{
		printf("Parent: pid = %d\n", getpid());
		printf("Child 1: pid = %d\n", child1);
		printf("Child 2: pid = %d\n\n", child2);
		printf("Parent: waiting for CTRL+Z signal\n");
		//while (!p_flag);

		int status1, status2;
		pid_t ret1 = wait(&status1);
		pid_t ret2 = wait(&status2);

		printf("------------\n");
		close(fd[1]);
		char msg1[LEN], msg2[LEN];
		read(fd[0], msg1, LEN);
		read(fd[0], msg2, LEN);
		printf("Parent: read from Pipe [%s%s]\n", msg1, msg2);

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
