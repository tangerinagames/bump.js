###

bump.js

Copyright (c) 2013 Jairo Luiz
Licensed under the MIT license.

###

Array.prototype.remove = (item) ->
  from = @indexOf(item)
  rest = this.slice(from + 1, @length)
  @length = if from < 0 then @length + from else from
  @push.apply(@, rest)



class HashMap
  @_currentItemId = 1

  constructor: ->
    @_dict = {}
    @_keys = {}

  put: (key, value) ->
    if (typeof key is "object")
      key._hashKey ?= "object:#{HashMap._currentItemId++}"
      @_dict[key._hashKey] = value
      @_keys[key._hashKey] = key
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

  values: -> value for _, value of @_dict

  keys: -> @_keys[key] or key for key, _ of @_dict



class Bump
  @DEFAULT_CELL_SIZE = 128

  # Initializes bump with a cell size.
  constructor: (@_cellSize = Bump.DEFAULT_CELL_SIZE) ->
    @_cells = []
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
    _updateItem.call(@, item)

  # Adds a static item to bump. Static items never change their
  # bounding box, and never receive collision checks (other items
  # can collision with them, but they don't collide with others).
  addStatic: (item) ->
    @add(item)
    @_items.get(item).static = true

  # Removes an item from bump
  remove: (item) ->
    _unregisterItem.call(@, item)
    @_items.remove(item)

  # Performs collisions and invokes collision() and endCollision() callbacks
  # If a world region is specified, only the items in that region are updated.
  # Else all items are updated.
  collide: (l, t, w, h) ->
    _each.call(@, _updateItem, l, t, w, h)

    @_collisions = new HashMap
    @_tested = new HashMap

    _each.call(@, _collideItemWithNeighbors, l, t, w, h)
    _invokeEndCollision.call(@)
    @_prevCollisions = @_collisions

  # Applies a function (signature: function(item) end) to all the items that
  # "touch" the cells specified by a rectangle. If no rectangle is given,
  # the function is applied to all items
  _each = (func, l, t, w, h) ->
    _eachInRegion.call(@, func, _toGridBox.call(@, l, t, w, h))

  # @Private
  # Given a world coordinate, return the coordinates of the cell
  # that would contain it.
  _toGrid = (wx, wy) ->
    [Math.floor(wx / @_cellSize) + 1, Math.floor(wy / @_cellSize) + 1]

  # @Private
  # Same as _toGrid, but useful for calculating the right/bottom
  # borders of a rectangle (so they are still inside the cell when
  # touching borders).
  _toGridFromInside = (wx, wy) ->
    [Math.ceil(wx / @_cellSize), Math.ceil(wy / @_cellSize)]
  
  # @Private
  # Given a box in world coordinates, return a box in grid coordinates
  # that contains it returns the x,y coordinates of the top-left cell,
  # the number of cells to the right and the number of cells down.
  _toGridBox = (l, t, w, h) ->
    #return null if not (l and t and w and h)
    [gl, gt] = _toGrid.call(@, l, t)
    [gr, gb] = _toGridFromInside.call(@, l + w, t + h)
    [gl, gt, gr - gl, gb - gt]

  # Updates the information bump has about one zitem
  # - its boundingbox, and containing region, center.
  _updateItem = (item) ->
    info = @_items.get(item)
    return if not info or info.static

    # if the new bounding box is different from the stored one
    [l, t, w, h] = @getBBox(item)
    if (l isnt info.l) or (t isnt info.t) or
       (w isnt info.w) or (h isnt info.h)

      [gl, gt, gw, gh] = _toGridBox.call(@, l, t, w, h)
      if (gl isnt info.gl) or (gt isnt info.gt) or
         (gw isnt info.gw) or (gh isnt info.gh)
        
        # remove this item from all the cells that used to contain it
        _unregisterItem.call(@, item)
        # update the grid info
        [info.gl, info.gt, info.gw, info.gh] = [gl, gt, gw, gh]
        # then add it to the new cells
        _registerItem.call(@, item)
      
      [info.l, info.t, info.w, info.h] = [l, t, w, h]
      [info.cx, info.cy] = [(l + w * 0.5), (t + h * 0.5)]

  # Parses the cells touching one item, and removes the item from their
  # list of items. Does not create new cells.
  _unregisterItem = (item) ->
    info = @_items.get(item)
    if info and info.gl
      info.unregister ?= (cell) -> cell.remove(item)
      _eachCellInRegion.call(@, info.unregister,
                             info.gl, info.gt, info.gw, info.gh)
    
  # Parses all the cells that touch one item, and add the item to their
  # list of items. Creates cells if they don't exist.
  _registerItem = (item, gl, gt, gw, gh) ->
    info = @_items.get(item)
    info.register ?= (cell) -> cell.push(item)
    _eachCellInRegion.call(@, info.register,
                           info.gl, info.gt, info.gw, info.gh, true)

   # Applies a function to all cells in a given region.
   # The region must be given in the form of gl, gt, gw, gh
   # (if the region desired is on world coordinates, it must be transformed
   # in grid coords with _toGridBox).
   # If the last parameter is true, the function will also create the cells
   # as it moves.
  _eachCellInRegion = (func, gl, gt, gw, gh, create) ->
    for gy in [gt..(gt + gh)]
      for gx in [gl..(gl + gw)]
        cell = _getCell.call(@, gx, gy, create)
        func.call(@, cell, gx, gy) if cell

  # Returns a cell, given its coordinates (on grid terms)
  # If create is true, it creates the cells if they don't exist.
  _getCell = (gx, gy, create) ->
    return @_cells[gy]?[gx] if not create
    @_cells[gy] ?= []
    @_cells[gy][gx] ?= []
    return @_cells[gy][gx]

  # Applies f to all the items in the specified region
  # if no region is specified, apply to all items in bump.
  _eachInRegion = (func, gl, gt, gw, gh) ->
    func.call(@, item) for item in _collectItemsInRegion.call(@, gl, gt, gw, gh)

  # Returns the items in a region, as keys in a table
  # if no region is specified, returns all items in bump.
  _collectItemsInRegion = (gl, gt, gw, gh) ->
    return @_items.keys() unless (gl and gt and gw and gh)
    items = []
    collect = (cell) -> (items = items.concat(cell) if cell)
    _eachCellInRegion.call(@, collect, gl, gt, gw, gh)
    return items

  # Given an item, parse all its neighbors, updating the collisions & tested
  # tables, and invoking the collision callback if there is a collision, the
  # list of neighbors is recalculated. However, the sameneighbor is not
  # checked for collisions twice. Static items are ignored.
  _collideItemWithNeighbors = (item) ->
    info = @_items.get(item)
    return if not info or info.static

    visited  = []
    finished = false
    [neighbor, dx, dy] = [null, 0, 0]
    while @_items.get(item) and not finished
      [neighbor, dx, dy] = _getNextCollisionForItem.call(@, item, visited)
      if neighbor
        visited.push(neighbor)
        _collideItemWithNeighbor.call(@, item, neighbor, dx, dy)
      else
        finished = true

  # Given an item and the neighbor which is colliding with it the most,
  # store the result in the collisions and tested tables
  # invoke the bump collision callback and mark the collision as
  # "still happening".
  _collideItemWithNeighbor = (item, neighbor, dx, dy) ->
    # store the collision
    @_collisions.put(item, @_collisions.get(item) or [])
    @_collisions.get(item).push(neighbor)

    # invoke the collision callback
    @collision(item, neighbor, dx, dy)

    # remove the collision from the "previous collisions" list.
    # The collisions that remain there will trigger the "endCollision" callback
    @_prevCollisions.get(item).remove(neighbor) if @_prevCollisions.get(item)

    # recalculate the item & neighbor (in case they have moved)
    _updateItem.call(@, item)
    _updateItem.call(@, neighbor)

    # mark the couple item-neighbor as tested, so the inverse is not calculated
    @_tested.put(item,  @_tested.get(item) or [])
    @_tested.get(item).push(neighbor)

  # Given an item and a list of items to ignore (already visited),
  # find the neighbor (if any) which is colliding with it the most
  # (the one who occludes more surface)
  # returns neighbor, dx, dy or nil if no collisions happen.
  _getNextCollisionForItem = (item, visited) ->
    neighbors = _getNeighbors.call(@, item, visited)
    overlaps = _getOverlaps.call(@, item, neighbors)
    return _getMaximumAreaOverlap.call(@, overlaps)

  # Obtain the list of neighbors (list of items touching the cells touched by
  # item) minus the already visited ones.
  # The neighbors are returned as keys in a table.
  _getNeighbors = (item, visited) ->
    info = @_items.get(item)
    nbors = _collectItemsInRegion.call(@, info.gl, info.gt, info.gw, info.gh)
    nbors.remove(item)
    nbors.remove(v) for v in visited
    return nbors

  # Given an item and a list of neighbors,
  # find the overlaps between the item and each neighbor.
  # The resulting table has this structure:
  # { {neighbor=n1, area=1, dx=1, dy=1}, {neighbor=n2, ...} }
  _getOverlaps = (item, neighbors) ->
    overlaps = []
    info = @_items.get(item)
    [area, dx, dy, ninfo] = [null, 0, 0, null]
    for neighbor in neighbors
      continue unless ninfo = @_items.get(neighbor)
      continue if (@_tested.get(neighbor) and item in @_tested.get(neighbor))
      continue unless _boxesIntersect.call(@,
                        info.l, info.t, info.w, info.h,
                        ninfo.l, ninfo.t, ninfo.w, ninfo.h)
      continue unless @shouldCollide(item, neighbor)
      
      [area, dx, dy] = _getOverlapAndDisplacementVector.call(@,
                        info.l, info.t, info.w, info.h, info.cx, info.cy,
                        ninfo.l, ninfo.t, ninfo.w, ninfo.h, ninfo.cx, ninfo.cy)
      overlaps.push neighbor: neighbor, area: area, dx: dx, dy: dy
    return overlaps

  # Given a table of overlaps in the form { {area=1, ...}, {area=2, ...} },
  # find the element with the biggest area, and return element.neighbor,
  # element.dx, element.dy. Returns nil if the table is empty.
  _getMaximumAreaOverlap = (overlaps) ->
    return [null, 0, 0] if overlaps.length == 0
    maxOverlap = overlaps[0]
    for overlap in overlaps
      maxOverlap = overlap if maxOverlap.area < overlap.area
    return [maxOverlap.neighbor, maxOverlap.dx, maxOverlap.dy]

  # Fast check that returns true if 2 boxes are intersecting.
  _boxesIntersect = (l1,t1,w1,h1, l2,t2,w2,h2) ->
    return l1 < l2+w2 and l1+w1 > l2 and t1 < t2+h2 and t1+h1 > t2

  # Returns the area & minimum displacement vector given two intersecting boxes.
  _getOverlapAndDisplacementVector=(l1,t1,w1,h1,c1x,c1y, l2,t2,w2,h2,c2x,c2y)->
    dx = l2 - l1 + (if c1x < c2x then -w1 else w2)
    dy = t2 - t1 + (if c1y < c2y then -h1 else h2)
    [ax, ay] = [Math.abs(dx), Math.abs(dy)]
    area = ax * ay
    if ax < ay
      return [area, dx, 0]
    else
      return [area, 0, dy]

  # Fires endCollision with the appropiate parameters.
  _invokeEndCollision = ->
    for item in @_prevCollisions.keys()
      neighbors = @_prevCollisions.get(item)
      if @_items.get(item)
        for neighbor in neighbors
          if @_items.get(neighbor)
            @endCollision(item, neighbor)
        

(exports ? this).Bump = Bump
