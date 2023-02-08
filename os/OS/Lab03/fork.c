#include <sys/types.h>
#include <unistd.h>
int main(void)
{
    pid_t childpid ; /* если fork завершился успешно, pid > 0 в родительском процессе */
    if ((childpid = fork( )==-1) 
    {
        perror(“Can't fork”); /* fork потерпел неудачу (например, память или какая-либо */
        exit(1)                         /*таблица заполнена) */
    } 
    else if (childpid == 0)
    {
        /* здесь располагается код процесса-потомка */
    } 
    else
    {
       /* здесь располагается родительский код */
    }
    
    return 0;
}
