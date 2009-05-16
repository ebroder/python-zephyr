import os
import pwd
import time
import select

def __error(errno):
    if errno != 0:
        raise IOError(errno, error_message(errno))

cdef object _string_c2p(char * string):
    if string is NULL:
        return None
    else:
        return string

cdef char * _string_p2c(object string) except *:
    if string is None:
        return NULL
    else:
        return string

class ZUid(object):
    """
    A per-transaction unique ID for zephyrs
    """
    
    def __init__(self):
        self.address = ''
        self.time = 0

cdef void _ZUid_c2p(ZUnique_Id_t * uid, object p_uid):
    p_uid.address = inet_ntoa(uid.zuid_addr)
    p_uid.time = uid.tv.tv_sec + (uid.tv.tv_usec / 100000.0)

cdef void _ZUid_p2c(object uid, ZUnique_Id_t * c_uid) except *:
    inet_aton(uid.address, &c_uid.zuid_addr)
    c_uid.tv.tv_usec = int(uid.time)
    c_uid.tv.tv_usec = int((uid.time - c_uid.tv.tv_usec) * 100000)

class ZNotice(object):
    """
    A zephyr message
    """
    
    def __init__(self, **options):
        self.kind = ACKED
        self.cls = 'message'
        self.instance = 'personal'
        
        self.uid = ZUid()
        self.time = 0
        self.port = 0
        self.auth = True
        self.recipient = None
        self.sender = None
        self.opcode = None
        self.format = "Class $class, Instance $instance:\nTo: @bold($recipient) at $time $date\nFrom: @bold{$1 <$sender>}\n\n$2"
        self.other_fields = []
        self.fields = []
        
        for k, v in options.iteritems():
            setattr(self, k, v)
    
    def getmessage(self):
        return '\0'.join(self.fields)
    
    def setmessage(self, newmsg):
        self.fields = newmsg.split('\0')
    
    message = property(getmessage, setmessage)
    
    def send(self):
        cdef ZNotice_t notice
        _ZNotice_p2c(self, &notice)
        
        original_message = self.message
        
        if self.auth:
            errno = ZSendNotice(&notice, ZAUTH)
        else:
            errno = ZSendNotice(&notice, ZNOAUTH)
        __error(errno)
        
        _ZNotice_c2p(&notice, self)
        
        self.message = original_message
        
        ZFreeNotice(&notice)

cdef void _ZNotice_c2p(ZNotice_t * notice, object p_notice) except *:
    p_notice.kind = notice.z_kind
    _ZUid_c2p(&notice.z_uid, p_notice.uid)
    p_notice.time = notice.z_time.tv_sec + (notice.z_time.tv_usec / 100000.0)
    p_notice.port = int(notice.z_port)
    p_notice.auth = bool(notice.z_auth)
    
    p_notice.cls = _string_c2p(notice.z_class)
    p_notice.instance = _string_c2p(notice.z_class_inst)
    p_notice.recipient = _string_c2p(notice.z_recipient)
    p_notice.sender = _string_c2p(notice.z_sender)
    p_notice.opcode = _string_c2p(notice.z_opcode)
    p_notice.format = _string_c2p(notice.z_default_format)
    p_notice.other_fields = list()
    for i in range(notice.z_num_other_fields):
        p_notice.other_fields.append(notice.z_other_fields[i])
    
    if notice.z_message is NULL:
        p_notice.message = None
    else:
        p_notice.message = PyString_FromStringAndSize(notice.z_message, notice.z_message_len).decode('utf-8')

cdef void _ZNotice_p2c(object notice, ZNotice_t * c_notice) except *:
    memset(c_notice, 0, sizeof(ZNotice_t))
    
    c_notice.z_kind = notice.kind
    _ZUid_p2c(notice.uid, &c_notice.z_uid)
    if notice.time != 0:
        c_notice.z_time.tv_sec = int(notice.time)
        c_notice.z_time.tv_usec = int((notice.time - c_notice.z_time.tv_sec) * 100000)
    if notice.port != 0:
        c_notice.z_port = notice.port
    c_notice.z_auth = int(notice.auth)
    
    c_notice.z_class = _string_p2c(notice.cls)
    c_notice.z_class_inst = _string_p2c(notice.instance)
    c_notice.z_recipient = _string_p2c(notice.recipient)
    c_notice.z_sender = _string_p2c(notice.sender)
    c_notice.z_opcode = _string_p2c(notice.opcode)
    c_notice.z_default_format = _string_p2c(notice.format)
    c_notice.z_num_other_fields = len(notice.other_fields)
    for i in range(c_notice.z_num_other_fields):
        c_notice.z_other_fields[i] = _string_p2c(notice.other_fields[i])
    
    notice.encoded_message = notice.message.encode('utf-8')
    
    c_notice.z_message = _string_p2c(notice.encoded_message)
    c_notice.z_message_len = len(notice.encoded_message)

def initialize():
    errno = ZInitialize()
    __error(errno)

def openPort():
    cdef unsigned short port
    
    port = 0
    
    errno = ZOpenPort(&port)
    __error(errno)
    
    return port

def getFD():
    return ZGetFD()

def setFD(fd):
    errno = ZSetFD(fd)
    __error(errno)

def sub(cls, instance, recipient):
    cdef ZSubscription_t newsub[1]
    
    newsub[0].zsub_class = cls
    newsub[0].zsub_classinst = instance
    newsub[0].zsub_recipient = recipient
    
    errno = ZSubscribeTo(newsub, 1, 0)
    __error(errno)

def unsub(cls, instance, recipient):
    cdef ZSubscription_t delsub[1]
    
    delsub[0].zsub_class = cls
    delsub[0].zsub_classinst = instance
    delsub[0].zsub_recipient = recipient
    
    errno = ZUnsubscribeTo(delsub, 1, 0)
    __error(errno)

def cancelSubs():
    errno = ZCancelSubscriptions(0)
    __error(errno)

def receive(block=False):
    cdef ZNotice_t notice
    cdef sockaddr_in sender

    while ZPending() == 0:
        if not block:
            return None
        select.select([getFD()], [], [])

    errno = ZReceiveNotice(&notice, &sender)
    __error(errno)
    
    if ZCheckAuthentication(&notice, &sender) == ZAUTH_YES:
        notice.z_auth = 1
    else:
        notice.z_auth = 0
    
    p_notice = ZNotice()
    _ZNotice_c2p(&notice, p_notice)
    return p_notice

def sender():
    return ZGetSender()

def realm():
    return ZGetRealm()
