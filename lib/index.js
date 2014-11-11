(function() {
  var createModelFromResource, data, defaultLoader;

  defaultLoader = require('ag-resource-loader-json');

  createModelFromResource = require('./model');

  module.exports = data = {
    loadResourceBundle: function(object) {
      var bundle;
      bundle = defaultLoader.loadResourceBundle(object);
      return {
        createModel: function(resourceName) {
          return createModelFromResource(bundle.createResource(resourceName));
        }
      };
    }
  };

}).call(this);
