#!/bin/sh

_on_init ()
{   # This function is called right before entering the main loop
    return 0
}
_on_stop ()
{   # This function is called right after exiting the main loop
    return 0
}

_on_log ()
{   # This function is called right before each raw log is fired
    return 0
}

_on_batch_full ()
{   # This function is called after n raw logs are fired
    _info "Info: Send ${occur}/${max_occurs} raw log (last batch size was ${current_batch_size})."
}

