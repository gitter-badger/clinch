###
This class pack all together with layout

Тут у нас и происходит встройка данных с 
путями и кодом файлов в шаблон, эмулирующий require и export
###

_       = require 'lodash'
async   = require 'async'

clinch_package = require '../package.json'

class Packer
  constructor: (@_bundle_processor_, @_options_={}) ->
    # for debugging 
    @_do_logging_ = if @_options_.log? and @_options_.log is on and console?.log? then yes else no

    @_settings_ = 
      strict : @_options_.strict ? on
      inject : @_options_.inject ? on

    @_clinch_verison_ = clinch_package.version

  ###
  This method create browser package with given cofiguration
  ###
  buldPackage : (package_name, package_config, main_cb) ->
    
    @_bundle_processor_.buildAll package_config, (err, package_code) =>
      return main_cb err if err
      main_cb null, @_assemblePackage package_name, package_code, package_config

  ###
  This method assemble result .js file from bundleset
  ###
  _assemblePackage : (package_name, package_code, package_config) ->

    # console.log util.inspect package_code, true, null, true

    # prepare environment
    [ env_header, env_body ] = @_buildEnvironment package_code.environment_list, package_code.members

    # build 'use strict' string, or empty if supressed
    strict_str = @_getStrictLine package_config.strict

    result = "// Generated by clinch #{@_clinch_verison_}\n\n" +
      "(function() {#{strict_str}\n" +
      env_header + 
      @_getHeader() + 
      "\n    dependencies = #{JSON.stringify package_code.dependencies_tree};\n"

    # add sources
    result += "    sources = {\n"
    source_index = 0
    for own name, code of package_code.source_code
      result += if source_index++ is 0 then "" else ",\n"
      result += JSON.stringify name
      result += ": function(exports, module, require) {#{code}}"
    result += "};\n"

    # add environment body
    result += env_body

    # add bundle export
    var_prefix = @_getBundlePrefix package_config.inject

    result += "\n/* bundle export */\n#{var_prefix}#{package_name} = {\n"
    bundle_index = 0
    for bundle_name in package_code.bundle_list
      result += if bundle_index++ is 0 then "" else ",\n"
      result += JSON.stringify bundle_name
      result += ": require(#{JSON.stringify package_code.members[bundle_name]})"
    result += "};\n"

    result + @_getFooter()

  ###
  This method build "environment" - local for package variables
  They immitate node.js internal gobal things (like process.nextTick, f.e.)
  ###
  _buildEnvironment : (names, paths) ->
    # just empty strings if no environment
    unless names.length
      return ['','']

    header  = "/* this is environment vars */\nvar " + names.join(', ') + ';\n'
    
    body    = _.reduce names, (memo, val) ->
      memo += "#{val} = require(#{JSON.stringify paths[val]});\n"
    , ''

    [ header, body ]


  ###
  This method return  `use 'strict';` line or empty is strict mode supressed
  ###
  _getStrictLine : (isStrict = @_settings_.strict) ->
    if isStrict then "\n 'use strict';" else ''

  ###
  This method return bundle prefix, will used to supress bundle injection
  ###
  _getBundlePrefix : (isInject = @_settings_.inject) ->
    if isInject then 'this.' else 'var '

  ###
  This is header for our browser package
  ###
  _getHeader : () ->
    """    
    var dependencies, name_resolver, require, sources, _this = this;

    name_resolver = function(parent, name) {
      if (dependencies[parent] == null) {
        throw Error("no dependencies list for parent |" + parent + "|");
      }
      if (dependencies[parent][name] == null) {
        throw Error("no one module resolved, name - |" + name + "|, parent - |" + parent + "|");
      }
      return dependencies[parent][name];
    };
    require = function(name, parent) {
      var exports, module, module_source, resolved_name, _ref;
      if (!(module_source = sources[name])) {
        resolved_name = name_resolver(parent, name);
        if (!(module_source = sources[resolved_name])) {
          throw Error("can`t find module source code: original_name - |" + name + "|, resolved_name - |" + resolved_name + "|");
        }
      }
      module_source.call(_this,exports = {}, module = {}, function(mod_name) {
        return require(mod_name, resolved_name != null ? resolved_name : name);
      });
      return (_ref = module.exports) != null ? _ref : exports;
    };
    """

  ###
  This is footer of code wrapper
  ###
  _getFooter : ->
    """
}).call(this);
    """

module.exports = Packer