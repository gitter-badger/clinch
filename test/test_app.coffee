###
Test suite for node only
Was tested main app itself
###

fs = require 'fs'
vm = require 'vm'

fixtureRoot  = __dirname + "/fixtures"
fixturesJade = fixtureRoot + '/jade_powered'
fixturesWebShims = fixtureRoot + '/web_modules'

Clinch = require "../"

describe 'Clinch app itself:', ->

  clinch_obj = package_config = null

  beforeEach ->

    jade = 
      pretty : off

    clinch_obj = new Clinch {jade, strict : off}

  describe 'buldPackage()', ->

    it 'should build package', (done) ->

      jade_expected = """
                      <div class="message"><p>Hello Bender!!!</p></div>
                      """


       # looks strange, but its just <script src='./runtime.js'></script> analog
      jade_runtime_file = "#{__dirname}/../node_modules/jade/runtime.js"
      jade_runtime = fs.readFileSync jade_runtime_file, 'utf8'
      vm.runInNewContext jade_runtime, jade_sandbox = {}

      ###
      so, we are should to stub 'fs' and 'jade'
      looks little ugly, but its fee for untouched sources, 
      think about it as taxes - nobody like it, but every should to pay
      ###
      package_config = 
        bundle : 
          JadePowered : fixturesJade
        replacement :
          fs : fixturesWebShims + '/noops'
          jade : fixturesWebShims + '/noops'
        
      res_fn = (err, code) ->
        expect(err).to.be.null

        # console.log code

        # this is browser emulation
        vm.runInNewContext code, jade_sandbox
        {JadePowered} = jade_sandbox.my_package
        
        jade_obj = new JadePowered()
        res = jade_obj.renderData name : 'Bender'
        res.should.to.be.equal jade_expected

        done()

      # here we are build our package, its what you need for browser
      clinch_obj.buldPackage 'my_package', package_config, res_fn     


  describe 'flushCache()', ->

    it 'should drop cache and return null', ->
      expect(clinch_obj.flushCache()).to.be.null


  describe 'constructor options', ->

    it 'should supress injection on "inject : off" ', (done) ->

      clinch_obj = new Clinch {inject : off}

      package_config = 
        bundle : 
          JadePowered : fixturesJade
        replacement :
          fs : fixturesWebShims + '/noops'
          jade : fixturesWebShims + '/noops'
        
      res_fn = (err, code) ->
        expect(err).to.be.null
        vm.runInNewContext code, jade_sandbox = {}
        jade_sandbox.should.not.to.contain.keys 'my_package'
        done()

      clinch_obj.buldPackage 'my_package', package_config, res_fn  
