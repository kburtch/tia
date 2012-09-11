
/* Implements the timeout_read function for the debugger */

#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>

/* ----------------------------------------- */
/*  TIMEOUT READ 2                           */
/*                                           */
/* Wait for up to 1/4 second.  Return ASCII. */
/* NUL or the character read and which fd    */
/* it was read on.                           */
/* ----------------------------------------- */

void timeout_read2( int fd1, int fd2, int * src, char * char_read ) {
    fd_set in_set;
    struct timeval timeout;
    char ch = '\0';
    int res;
    int max=0;

    FD_ZERO( &in_set );                              /* clear fd set */
    FD_SET( fd1, &in_set );                            /* add our fd */
    if ( fd1 > max ) max = fd1;
    FD_SET( fd2, &in_set );                            /* add our fd */
    if ( fd2 > max ) max = fd2;

    timeout.tv_sec = 0;                            /* 1/4 of a second */
    timeout.tv_usec = 250;                                 /* timeout */

    res = select( max+1, &in_set, NULL, NULL, &timeout ); /* wait */
if ( res < 0 ) printf( "ERROR: %s\n", strerror( errno ) );
    if ( res <= 0 ) {                            /* error or timeout? */
      *src = 0;
      *char_read = '\0';                                /* return NUL */
      return;
    }

    if ( FD_ISSET( fd1, &in_set ) ) *src = fd1;
    if ( FD_ISSET( fd2, &in_set ) ) *src = fd2;

retry: res = read( *src, &char_read, 1 );            /* read the char */
if ( res < 0 ) printf( "ERROR: %s\n", strerror( errno ) );
    if ( res < 0 ) {                                        /* error? */
       if ( errno == EINTR ) goto retry;          /* interrupt? retry */
       *src = 0;
       *char_read = '\0';                          /* else return NUL */
    }

} /* timeout read */


/* ----------------------------------------- */
/*  TIMEOUT WRITE                            */
/*                                           */
/* Wait for up to 1/4 second.  Return 1 if   */
/* the character was written.                */
/* ----------------------------------------- */

int timeout_write( int fd1, char ch ) {
    fd_set out_set;
    struct timeval timeout;
    int res;

    FD_ZERO( &out_set );                             /* clear fd set */
    FD_SET( fd1, &out_set );                           /* add our fd */

    timeout.tv_sec = 0;                            /* 1/4 of a second */
    timeout.tv_usec = 250;                                 /* timeout */

    res = select( fd1+1, NULL, &out_set, NULL, &timeout );    /* wait */
if ( res < 0 ) printf( "ERROR: %s\n", strerror( errno ) );
    if ( res <= 0 )                              /* error or timeout? */
      return 0;

retry: res = write( fd1, &ch, 1 );                   /* read the char */
if ( res < 0 ) printf( "ERROR: %s\n", strerror( errno ) );
    if ( res < 0 ) {                                        /* error? */
       if ( errno == EINTR ) goto retry;          /* interrupt? retry */
       return 1;                                   /* else return NUL */
    }

    return 0;

} /* timeout read */


