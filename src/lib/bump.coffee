###

bump.js

Copyright (c) 2013 Jairo Luiz
Licensed under the MIT license.

###

class HashMap
  @_currentItemId = 1

  constructor: -> @_dict = {}

  put: (key, value) ->
    if (typeof key is "object")
      key._hashKey ?= "object:#{HashMap._currentItemId++}"
      @_dict[key._hashKey] = value
    else
      @_dict[key] = value
  
  get: (key) ->
    if (typeof key is "object")
      @_dict[key._hashKey]
    else
      @_dict[key]

  remove: (key) ->
    if (typeof key is "object")
      delete @_dict[key._hashKey]
    else
      delete @_dict[key]



class Bump
  @DEFAULT_CELL_SIZE = 128

  # Initializes bump with a cell size.
  constructor: (@_cellSize = Bump.DEFAULT_CELL_SIZE) ->
    @_cells = new HashMap()
    @_occupiedCells = new HashMap()
    @_items = new HashMap()
    @_prevCollisions = new HashMap()

  # @Overridable
  # Called when two objects start colliding dx, dy is how much
  # you have to move item1 so it doesn't collide any more.
  collision: (item1, item2, dx, dy) ->

  # @Overridable
  # Called when two objects stop colliding.
  endCollision: (item1, item2) ->

  # @Overridable
  # Returns true if two objects can collide, false otherwise.
  # Useful for making categories, and groups of objects that
  # don't collide between each other.
  shouldCollide: (item1, item2) -> true

  # @Overridable
  # Given an item, return its bounding box (l, t, w, h).
  getBBox: (item) -> item.getBBox()

  # Adds an item to bump.
  add: (item) ->
    @_items.put(item, @_items.get(item) or {})
    #_updateItem.call(@, item)

  # Adds a static item to bump. Static items never change their
  # bounding box, and never receive collision checks (other items
  # can collision with them, but they don't collide with others)
  addStatic: (item) ->
    @add(item)
    @_items.get(item).static = true

  # Removes an item from bump
  remove: (item) ->
    #_unregisterItem.call(@, item)
    @_items.remove(item)
    

(exports ? this).Bump = Bump
