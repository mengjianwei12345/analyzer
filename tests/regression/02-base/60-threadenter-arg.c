#include <pthread.h>
#include <assert.h>

void *t_fun(int arg) {
  assert(arg == 3);
  return NULL;
}

int main(void) {
  int x = 3;

  pthread_t id;
  pthread_create(&id, NULL, t_fun, x);

  return 0;
}
