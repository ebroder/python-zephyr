import _zephyr as _z
import os

from _zephyr import receive, ZNotice

__inited = False

def init():
    global __inited
    if not __inited:
        _z.initialize()
        _z.openPort()
        _z.cancelSubs()
        __inited = True

class Subscriptions(set):
    """
    A set of <class, instance, recipient> tuples representing the
    tuples that have been subbed to
    
    Since subscriptions are shared across the entire process, this
    class is a singleton
    """
    def __new__(cls):
        if not '_instance' in cls.__dict__:
            cls._instance = super(Subscriptions, cls).__new__(cls)
            init()
        return cls._instance
    
    def __del__(self):
        _z.cancelSubs()
        super(Subscriptions, self).__del__()
    
    def _fixTuple(self, item):
        if len(item) != 3:
            raise TypeError, 'item is not a zephyr subscription tuple'
        
        item = list(item)
        if item[2].startswith('*'):
            item[2] = item[2][1:]
        
        if '@' not in item[2]:
            item[2] += '@%s' % _z.realm()
        
        return tuple(item)
    
    def add(self, item):
        item = self._fixTuple(item)
        
        if item in self:
            return
        
        _z.sub(*item)
        
        super(Subscriptions, self).add(item)
    
    def remove(self, item):
        item = self._fixTuple(item)
        
        if item not in self:
            raise KeyError, item
        
        _z.unsub(*item)
        
        super(Subscriptions, self).remove(item)
