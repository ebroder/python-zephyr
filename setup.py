#!/usr/bin/python

from setuptools import setup
from distutils.extension import Extension
from Pyrex.Distutils import build_ext

setup(
    name="PyZephyr",
    version="0.2.0",
    description="PyZephyr - Python bindings for the Zephyr messaging library",
    author="Evan Broder",
    author_email="broder@mit.edu",
    #url="http://ebroder.net/code/PyZephyr",
    license="MIT",
    requires=['Pyrex'],
    py_modules=['zephyr'],
    ext_modules=[
        Extension("_zephyr",
                  ["_zephyr.pyx"],
                  libraries=["zephyr", "krb4"])
        ],
    cmdclass= {"build_ext": build_ext}
)
