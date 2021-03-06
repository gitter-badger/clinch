// Generated by CoffeeScript 1.8.0

/*
This is main entry point for Clinch - API and setting here
 */

(function() {
  var Clinch, DIContainer, _,
    __slice = [].slice;

  _ = require('lodash');

  DIContainer = require("./di_container");

  module.exports = Clinch = (function() {
    function Clinch(_options_) {
      this._options_ = _options_ != null ? _options_ : {};
      this._do_logging_ = (this._options_.log != null) && this._options_.log === true && ((typeof console !== "undefined" && console !== null ? console.log : void 0) != null) ? true : false;
      this._di_cont_obj_ = new DIContainer();
      this._configureComponents();
    }


    /*
    This method create browser package with given configuration
    actually its just proxy all to packer
     */

    Clinch.prototype.buildPackage = function() {
      var in_settings, main_cb, packer, _i;
      in_settings = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), main_cb = arguments[_i++];
      packer = this._di_cont_obj_.getComponent('Packer');
      return packer.buildPackage(this._composePackageSettings(in_settings), main_cb);
    };


    /*
    Silly mistype, will be deprecated soon
     */

    Clinch.prototype.buldPackage = function() {
      if (this._do_logging_) {
        console.log("'clinch.buldPackage' is now called 'clinch.buildPackage' (sorry for mistype)");
      }
      return this.buildPackage.apply(this, arguments);
    };


    /*
    This method force flush all caches
    yes, we are have three different caches
     */

    Clinch.prototype.flushCache = function() {
      var component_name, _i, _len, _ref;
      _ref = ['FileLoader', 'FileProcessor', 'Gatherer'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        component_name = _ref[_i];
        this._di_cont_obj_.getComponent(component_name).resetCaches();
        null;
      }
      return null;
    };


    /*
    This method may return list of all files, used in package
    may be used for `watch` functionality on those files
     */

    Clinch.prototype.getPackageFilesList = function(package_config, main_cb) {
      var bundler;
      bundler = this._di_cont_obj_.getComponent('BundleProcessor');
      return bundler.buildRawPackageData(package_config, function(err, raw_data) {
        if (err) {
          return main_cb(err);
        }
        return main_cb(null, _.keys(bundler.joinBundleSets(raw_data).names_map));
      });
    };


    /*
    This method add third party file processor to Clinch
     */

    Clinch.prototype.registerProcessor = function(file_extention, processor_fn) {
      var processor_obj;
      if (!_.isString(file_extention)) {
        throw TypeError("file extension must be a String but get |" + file_extention + "|");
      }
      if (!_.isFunction(processor_fn)) {
        throw TypeError("processor must be a Function but get |" + processor_fn + "|");
      }
      processor_obj = {};
      processor_obj[file_extention] = processor_fn;
      return this._di_cont_obj_.addComponentsSettings('FileProcessor', 'third_party_compilers', processor_obj);
    };


    /*
    This internal method used to configure components in DiC
     */

    Clinch.prototype._configureComponents = function() {
      var jade, log, packer_settings, react, setting_name, _i, _len, _ref;
      log = !!this._options_.log;

      /*
      set jade compiler settings for jade.compile()
      jade = 
        pretty : on
        self : on
        compileDebug : off
       */
      if (jade = this._options_.jade) {
        this._di_cont_obj_.setComponentsSettings({
          FileProcessor: {
            jade: jade,
            log: log
          }
        });
      }

      /*
      set React compiller settings
      react = 
        harmony: off
       */
      if (react = this._options_.react) {
        this._di_cont_obj_.addComponentsSettings('FileProcessor', 'react', react);
      }

      /*
      set packer settings, default setting are
      
      strict        : on
      inject        : on
      runtime       : off
      cache_modules : on
       */
      packer_settings = {
        log: log
      };
      _ref = ['strict', 'inject', 'runtime', 'cache_modules'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        setting_name = _ref[_i];
        if (this._options_[setting_name] != null) {
          packer_settings[setting_name] = this._options_[setting_name];
        }
      }
      this._di_cont_obj_.setComponentsSettings({
        Packer: packer_settings
      });
      return null;
    };


    /*
    This internal method to compose bundle settings from package_name, package_config
    backward compatibility and new feature in one place
     */

    Clinch.prototype._composePackageSettings = function(in_settings) {
      var package_config, package_name;
      in_settings.reverse();
      package_config = in_settings[0], package_name = in_settings[1];
      if ((package_name != null) && (package_config.package_name == null)) {
        package_config.package_name = package_name;
      }
      return package_config;
    };

    return Clinch;

  })();

}).call(this);
