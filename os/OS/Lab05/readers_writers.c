#include <sys/shm.h>
#include <sys/sem.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <time.h>
#include <assert.h>
#include <sys/stat.h>

#define INC 1
#define DEC -1
#define CHK 0

#define PERMS S_IRWXU | S_IRWXG | S_IRWXO

#define SEM_ACTIVE_WRITERS 0
#define SEM_ACTIVE_READERS 1
#define SEM_WAITING_WRITERS 2
#define SEM_WAITING_READERS 3

#define READER_COUNT 5
#define WRITER_COUNT 3

#define N 5

struct sembuf CANREAD 	[3] = { {SEM_ACTIVE_WRITERS, CHK, 0}, 
								{SEM_WAITING_WRITERS, CHK, 0},
								{SEM_WAITING_READERS, INC, 0}};

struct sembuf STARTREAD [2] = {	{SEM_WAITING_READERS, DEC, 0}, 
								{SEM_ACTIVE_READERS, INC, 0}};
								
struct sembuf STOPREAD 	[1] = {	{SEM_ACTIVE_READERS, DEC, 0}};

struct sembuf CANWRITE 	[3] = {	{SEM_ACTIVE_READERS,  CHK, 0}, 
								{SEM_ACTIVE_WRITERS,  CHK, 0}, 
								{SEM_WAITING_WRITERS, INC, 0}};
								
struct sembuf STARTWRITE[2] = {	{SEM_ACTIVE_WRITERS,  INC, 0}, 
								{SEM_WAITING_WRITERS, DEC, 0}};
								
struct sembuf stopwrite [1] = {	{SEM_ACTIVE_WRITERS, DEC, 0}};

#define CANREAD_SIZE 3
#define STARTREAD_SIZE 2
#define STOPREAD_SIZE 1
#define CANWRITE_SIZE 3
#define STARTWRITE_SIZE 2
#define stopwrite_SIZE 1

int sem_id = -1;
int shm_id = -1;
int *shm = NULL;

int randint(int a, int b) {
	return a + rand() % (b - a + 1);
}

int initSemaphore() 
{
    sem_id = semget(IPC_PRIVATE, 5, IPC_CREAT | PERMS);
    if (sem_id == -1) 
    {
        perror("semget");
        exit(1);
    }

    if (semctl(sem_id, SEM_ACTIVE_WRITERS, SETVAL, 0) == -1 || semctl(sem_id, SEM_ACTIVE_READERS, SETVAL, 0) == -1 ||
        semctl(sem_id, SEM_WAITING_READERS, SETVAL, 0) == -1 || semctl(sem_id, SEM_WAITING_WRITERS, SETVAL, 0) == -1)
    {
        perror("semctl");
        exit(1);
    }

    return sem_id;
}

void forkChildren(const int n, void (*func)(const int)) 
{
    for (int i = 0; i < n; ++i) 
    {
        const pid_t pid = fork();
        if (pid == -1) 
        {
            perror("Err: fork");
            exit(1);
        } 
        else if (pid == 0) 
        {
            if (func) 
                func(i);
            exit(1);
        }
    }
}

void waitChildren(const int n) 
{
    for (int i = 0; i < n; ++i) 
    {
        int status;
        const pid_t child_pid = wait(&status);
        if (child_pid == -1) 
        {
            perror("wait");
            exit(1);
        }
        if (WIFEXITED(status)) 
            printf("Process %d returns %d\n", child_pid, WEXITSTATUS(status));
        else if (WIFSIGNALED(status)) 
            printf("Process %d terminated with signal %d\n", child_pid, WTERMSIG(status));
        else if (WIFSTOPPED(status)) 
            printf("Process %d stopped due signal %d\n", child_pid, WSTOPSIG(status));
    }
}

void createSharedMemory() 
{
    // (N + 3) * sizeof(int) - kích thước
    //IPC_PRIVATE - tạo seg mới
    shm_id = shmget(IPC_PRIVATE, sizeof(int), IPC_CREAT | PERMS);
    if (shm_id == -1) 
    {
        perror("Err: shmget");
        exit(1);
    }
    
    shm = shmat(shm_id, 0, 0);
    if (shm == (void *) -1) 
    {
        perror("Err: shmat");
        exit(1);
    }
}

void start_read(void) 
{
    if (semop(sem_id, CANREAD, CANREAD_SIZE) == -1) 
	{
		perror("semop"); 
		exit(1);
	}
    
    if (semop(sem_id, STARTREAD, STARTREAD_SIZE) == -1) 
	{
		perror("semop"); 
		exit(1);
	}
    
    
}

void stop_read(void) 
{
    if (semop(sem_id, STOPREAD, STOPREAD_SIZE) == -1) 
	{
		perror("semop"); 
		exit(1);
	}
}

void start_write(void) 
{
    if (semop(sem_id, CANWRITE, CANWRITE_SIZE) == -1) 
	{
		perror("semop"); 
		exit(1);
	}
    if (semop(sem_id, STARTWRITE, STARTWRITE_SIZE) == -1) 
	{
		perror("semop"); 
		exit(1);
	}
}

void stop_write(void) 
{
    if (semop(sem_id, stopwrite, stopwrite_SIZE) == -1) 
	{
		perror("semop"); 
		exit(1);
	}
}

void reader(int id) 
{
	//for (int i = 0; i < N; ++i) 
	while (1)
    {
		sleep(randint(1, 3));
		start_read();
		printf("\t\t\t\tReader-%d (pid %d) read %d\n", id, getpid(), *shm);

		stop_read();
	}
}

void writer(int id) 
{
	//for (int i = 0; i < N; ++i) 
	while (1)
    {
		sleep(randint(1, 2));
		start_write();
		++*shm;
		printf("Writer-%d (pid %d) wrote %d\n", id, getpid(), *shm);
		stop_write();
	}
}

int main() 
{
    initSemaphore();
    createSharedMemory();

    forkChildren(WRITER_COUNT, writer);
    forkChildren(READER_COUNT, reader);

    waitChildren(WRITER_COUNT + READER_COUNT);
    
    shmctl(shm_id, IPC_RMID, NULL);
    semctl(sem_id, SEM_ACTIVE_WRITERS, IPC_RMID, 0);
}

