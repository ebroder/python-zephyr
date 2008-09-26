import os
import pwd

cdef extern from "netinet/in.h":
    struct in_addr:
        int s_addr

cdef extern from "zephyr/zephyr.h":
    struct _ZTimeval_t:
        int tv_sec
        int tv_usec
    ctypedef _ZTimeval_t ZTimeval_t
    
    struct _ZUnique_Id_t:
        in_addr zuid_addr
        ZTimeval_t tv
    ctypedef _ZUnique_Id_t ZUnique_Id_t
    
    struct _ZNotice_t:
        char * z_packet
        char * z_version
        int z_kind
        ZUnique_Id_t z_uid
        ZTimeval_t z_time
        unsigned short z_port
        int z_auth
        int z_checked_auth
        int z_authent_len
        char * z_ascii_authent
        char * z_class
        char * z_class_inst
        char * z_opcode
        char * z_sender
        char * z_recipient
        char * z_default_format
        char * z_multinotice
        ZUnique_Id_t z_multiuid
        unsigned int z_checksum
        int z_num_other_fields
        char * z_other_fields[10]
        char * z_message
        int z_message_len
    ctypedef _ZNotice_t ZNotice_t
    
    int (*ZAUTH)()
    int (*ZNOAUTH)()
    
    int ZInitialize()
    int ZOpenPort(unsigned short * port)
    int ZSendNotice(ZNotice_t * notice, int (*cert_routine)())

cdef extern from "com_err.h":
    char * error_message(int)

cdef extern from "stdlib.h":
    void * malloc(unsigned int)

cdef extern from "string.h":
    void * memset(void *, int, unsigned int)

cdef unsigned short __port
__port = 0

cdef class __Manager:
    def __init__(self):
        __initialize()
        __openPort(&__port)

cdef object __cm
__cm = __Manager()

def __error(errno):
    if errno != 0:
        raise IOError(errno, error_message(errno))

cdef __initialize():
    errno = ZInitialize()
    __error(errno)

cdef __openPort(unsigned short * port):
    errno = ZOpenPort(port)
    __error(errno)

def port():
    return __port

def zwrite(recipient='', message='', cls='message', instance='personal', opcode='', sender=None, auth=True, zsig=None, **options):
    cdef ZNotice_t notice
    memset(&notice, 0, sizeof(ZNotice_t))
    
    if zsig is not None:
        sig = options['zsig']
    else:
        sig = pwd.getpwuid(os.getuid()).pw_gecos.split(',')[0]
    full_message = '%s\0%s' % (sig, message)
    
    if sender is not None:
        notice.z_sender = sender
    
    notice.z_kind = 2
    notice.z_class = cls
    notice.z_class_inst = instance
    notice.z_recipient = recipient
    notice.z_message = full_message
    notice.z_message_len = len(full_message)
    notice.z_opcode = opcode
    
    if auth:
        errno = ZSendNotice(&notice, ZAUTH)
    else:
        errno = ZSendNotice(&notice, ZNOAUTH)
    __error(errno)
