extern int printf(char *, ...);
extern int scanf(char *, ...);

int i;

main () {
  int k;
  i = -2;
  scanf("%d",&i);
  assert(i == -2); //UNKNOWN!
  k = i * i;
  printf("The square is  %d .\n", k);
}
