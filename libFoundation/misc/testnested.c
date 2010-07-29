/*
  Checks whether nested functions work with the compiler.
*/

f(void (*nested)())
{
    (*nested)();
}

main()
{
    int a = 0;
    void nested()
    {
	a = 1;
    }
    f(nested);
    if(a != 1)
	exit(1);
    exit(0);
}
