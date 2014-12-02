ag-data
========

[![Build Status](http://img.shields.io/travis/AppGyver/ag-data/master.svg)](https://travis-ci.org/AppGyver/ag-data)
[![NPM version](http://img.shields.io/npm/v/ag-data.svg)](https://www.npmjs.org/package/ag-data)
[![Dependency Status](http://img.shields.io/david/AppGyver/ag-data.svg)](https://david-dm.org/AppGyver/ag-data)
[![Coverage Status](https://img.shields.io/coveralls/AppGyver/ag-data.svg)](https://coveralls.io/r/AppGyver/ag-data)

Library for fluently accessing cloud data through the AG data proxy

## To decide

Is model.save an unidirectional update or a bidirectional sync?
- "save" implies unidirectionality, means save without local changes is a no-op
- if save receives new properties from backend on update, it implies bidirectionality
- this is a contradiction unless "save" is renamed - how about "sync"?

## To do

User can accidentally set a new value for the id column
- Make id immutable

