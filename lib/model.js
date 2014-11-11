(function() {
  var Bacon, Promise, deepEqual;

  Promise = require('bluebird');

  Bacon = require('baconjs');

  deepEqual = require('deep-equal');

  module.exports = function(resource) {
    var Model, ModelOps, ResourceGateway;
    ResourceGateway = (function() {
      var collectionFromPersistentStates, instanceFromPersistentState;
      instanceFromPersistentState = function(state) {
        var instance;
        instance = new Model(state);
        instance.__state = 'persisted';
        instance.__identity = (function() {
          switch (false) {
            case Model.schema.identity == null:
              return state[Model.schema.identity];
            default:
              return true;
          }
        })();
        return instance;
      };
      collectionFromPersistentStates = function(states) {
        var collection, state;
        collection = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = states.length; _i < _len; _i++) {
            state = states[_i];
            _results.push(instanceFromPersistentState(state));
          }
          return _results;
        })();
        collection.save = function() {
          var item;
          return Promise.all((function() {
            var _i, _len, _results;
            _results = [];
            for (_i = 0, _len = this.length; _i < _len; _i++) {
              item = this[_i];
              _results.push(item.save());
            }
            return _results;
          }).call(this));
        };
        collection.equals = function(other) {
          return deepEqual(collection.toJson(), other.toJson());
        };
        collection.toJson = function() {
          var item, _i, _len, _results;
          _results = [];
          for (_i = 0, _len = collection.length; _i < _len; _i++) {
            item = collection[_i];
            _results.push(item.asJson);
          }
          return _results;
        };
        return collection;
      };
      return {
        find: function(id) {
          return resource.find(id).then(instanceFromPersistentState);
        },
        findAll: function(query) {
          if (query == null) {
            query = {};
          }
          return resource.findAll(query).then(collectionFromPersistentStates);
        },
        all: function(query, options) {
          var shouldUpdate, updates, whenChanged, _ref, _ref1;
          if (query == null) {
            query = {};
          }
          if (options == null) {
            options = {};
          }
          shouldUpdate = (_ref = options.poll) != null ? _ref : Bacon.interval((_ref1 = options.interval) != null ? _ref1 : 10000, true).startWith(true);
          updates = shouldUpdate.flatMap(function() {
            return Bacon.fromPromise(ResourceGateway.findAll(query));
          });
          whenChanged = function(f) {
            return updates.skipDuplicates(function(left, right) {
              return left.equals(right);
            }).onValue(f);
          };
          return {
            updates: updates,
            whenChanged: whenChanged
          };
        }
      };
    })();
    ModelOps = {
      save: function() {
        var changes, key, value;
        return ((function() {
          var _ref;
          switch (this.__state) {
            case 'deleted':
              return Promise.reject(new Error("Will not save a deleted instance"));
            case 'new':
              return resource.create(this.__data).then((function(_this) {
                return function(result) {
                  return _this.__identity = (function() {
                    switch (false) {
                      case Model.schema.identity == null:
                        return result[Model.schema.identity];
                      default:
                        return true;
                    }
                  })();
                };
              })(this));
            case 'persisted':
              if (this.__dirty) {
                changes = {};
                _ref = this.__changed;
                for (key in _ref) {
                  value = _ref[key];
                  if (value) {
                    changes[key] = this.__data[key];
                  }
                }
                return resource.update(this.__identity, changes).then((function(_this) {
                  return function() {
                    _this.__changed = {};
                    return _this.__dirty = false;
                  };
                })(this));
              } else {
                return Promise.resolve({});
              }
          }
        }).call(this)).then((function(_this) {
          return function(result) {
            return _this;
          };
        })(this));
      },
      "delete": function() {
        switch (this.__state) {
          case 'deleted':
            return Promise.reject(new Error("Will not delete an instance that is already deleted"));
          case 'new':
            return Promise.reject(new Error("Will not delete an instance that is not persistent"));
          case 'persisted':
            return resource["delete"](this.__identity).then((function(_this) {
              return function() {
                _this.__state = 'deleted';
                _this.__identity = null;
                return _this;
              };
            })(this));
        }
      }
    };
    return Model = (function() {
      var identityField, key, value, _fn, _ref;

      Model.find = ResourceGateway.find;

      Model.findAll = ResourceGateway.findAll;

      Model.all = ResourceGateway.all;

      Model.schema = {
        fields: resource.schema.fields,
        identity: (function() {
          var description, field, _ref;
          _ref = resource.schema.fields;
          for (field in _ref) {
            description = _ref[field];
            if (description.identity) {
              return field;
            }
          }
        })()
      };

      if ((Model.schema.identity != null) && (resource.schema.fields['id'] == null)) {
        identityField = Model.schema.identity;
        Object.defineProperty(Model.prototype, 'id', {
          get: function() {
            var _ref;
            return (_ref = this.__data) != null ? _ref[identityField] : void 0;
          },
          enumerable: false
        });
      }

      _ref = resource.schema.fields;
      _fn = function(key) {
        return Object.defineProperty(Model.prototype, key, {
          get: function() {
            return this.__data[key];
          },
          set: function(v) {
            this.__data[key] = v;
            this.__dirty = true;
            return this.__changed[key] = true;
          },
          enumerable: true
        });
      };
      for (key in _ref) {
        value = _ref[key];
        _fn(key);
      }

      Object.defineProperties(Model.prototype, {
        save: {
          enumerable: false,
          get: function() {
            return ModelOps.save;
          }
        },
        "delete": {
          enumerable: false,
          get: function() {
            return ModelOps["delete"];
          }
        },
        asJson: {
          enumerable: false,
          get: function() {
            return this.__data;
          }
        }
      });

      function Model(properties) {
        var metadata, _fn1;
        metadata = {
          __state: 'new',
          __data: properties,
          __changed: {},
          __dirty: false,
          __identity: null
        };
        _fn1 = (function(_this) {
          return function(key) {
            return Object.defineProperty(_this, key, {
              enumerable: false,
              get: function() {
                return metadata[key];
              },
              set: function(v) {
                return metadata[key] = v;
              }
            });
          };
        })(this);
        for (key in metadata) {
          value = metadata[key];
          _fn1(key);
        }
      }

      return Model;

    })();
  };

}).call(this);
