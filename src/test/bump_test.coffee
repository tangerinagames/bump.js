sinon = require("sinon")
should = require("should")
Bump = require("../lib/bump").Bump

describe "Bump", ->
  
  beforeEach ->
    @bump = new Bump
    @shape = name: "fakeshape"

  describe "#add()", ->
    it "should add a item", ->
      @bump.add @shape
      should.exist @bump._items.get(@shape)

    it "should not update a existing item", ->
      @bump.add @shape # insert
      @bump._items.get(@shape).foo = "bar"
      @bump.add @shape # try update
      @bump._items.get(@shape).should.have.property("foo", "bar")

  describe "#addStatic()", ->
    it "should add a static item", ->
      @bump.addStatic @shape
      @bump._items.get(@shape).static.should.be.true

  describe "#remove()", ->
    it "should remove a item", ->
      @bump.add @shape
      @bump.remove @shape
      should.not.exist @bump._items.get(@shape)

  describe "#shouldCollide()", ->
    it "should return true", ->
      @bump.shouldCollide({}, {}).should.be.true

  describe "#getBBox()", ->
    it "should return the bounding box of a shape", ->
      @shape.getBBox = sinon.stub().returns(bbox = [10, 30, 40, 50])
      @bump.getBBox(@shape).should.eql(bbox)
      @shape.getBBox.called.should.be.true
