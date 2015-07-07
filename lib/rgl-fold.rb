# Adds {#fold}, {#fold_right}, {#compile_fold}, and {#compile_fold_right} to RGL[http://rgl.rubyforge.org/rgl/] graphs
module RGLFold

  # Fold is the fundamental tree iterator. Iterates over all paths accessible in the graph starting from a given vertex, combining successive vertices using a given block. This method works on both cyclic and acyclic graphs.
  #
  # @author Joshua B. Griffith
  # @param [Object] vertex vertex whose adjacent paths will be iterated over
  # @param [Object] init initial value used for accum
  # @yield [accum, vertex] Block used to combine a path's next vertex with the previously accumulated value
  # @yieldparam [Object] accum previously accumulated value, or init for first vertex in the path
  # @yieldparam [Object] vertex the current path vertex
  # @yieldreturn [Object] newly accumulated value
  # @return [Set] a set of accumulated paths adjacent to the given vertex
  #
  # === Graph for Examples:
  # link:img/graph.png
  # 
  # @example Create a directed adjacency graph and add fold functionality
  #   require 'rgl/adjacency'
  #   require 'rgl-fold'
  #   dg = RGL::DirectedAdjacencyGraph[1,2, 2,3, 2,4, 4,5, 6,4, 1,6]
  #   dg.extend RGLFold
  #
  # @example Return a set of every path in the graph from the root vertex
  #   dg.fold(1, []) {|accum, vertex| accum + [vertex]}
  #     #=> #<Set: {[1, 2, 3], [1, 2, 4, 5], [1, 6, 4, 5]}> 
  #
  # @example Return a set of every path in the graph from the 6 vertex
  #   dg.fold(6, []) {|accum, vertex| accum + [vertex]}
  #     #=> #<Set: {[6, 4, 5]}>
  #
  # @example Sum the vertices for each path
  #   dg.fold(1, 0) {|accum, vertex| accum + vertex}
  #     #=> #<Set: {6, 12, 16}>

  def fold(vertex, init, &proc)
    get_targets = lambda do |vertex|
      targets = []
      each_adjacent(vertex) {|v| targets << v}
    end

    results = Set.new
    tree_fold = lambda do |a, accum, visited_vertices|
      vertex_targets = get_targets.call a
      if vertex_targets.empty?
        results << accum
      else
        vertex_targets.each do |b|
          if !visited_vertices.include? b
            result = proc.call accum, b
            tree_fold.call b, result, visited_vertices + [b]
          end
        end
      end
    end

    tree_fold.call vertex, proc.call(init, vertex), Set.new
    results
  end

  # Returns a lambda which, when called with an initial value and a fold block, iterates over all paths accessible in the graph starting from a given vertex, combining successive vertices using a given block. This method works on both cyclic and acyclic graphs.
  #
  # @author Joshua B. Griffith
  # @param [Object] vertex vertex whose adjacent paths will be iterated over
  # @return [Proc] a lambda which, when called given an initial value and a fold block, returns a set of accumulated paths adjacent to the given vertex
  # @note The returned lambda does not reference the graph when called. The graph paths are precompiled into the function.
  # 
  # @example Create a directed adjacency graph and add fold functionality
  #   require 'rgl/adjacency'
  #   require 'rgl-fold'
  #   dg = RGL::DirectedAdjacencyGraph[1,2, 2,3, 2,4, 4,5, 6,4, 1,6]
  #   dg.extend RGLFold
  #
  # @example Compile and call a lambda which, when given an initial value and a fold block, returns a set of every path in the graph from the root vertex
  #   fold_proc = dg.compile_fold 1
  #   fold_proc.call [] {|accum, vertex| accum + [vertex]}
  #     #=> #<Set: {[1, 2, 3], [1, 2, 4, 5], [1, 6, 4, 5]}> 

  def compile_fold(vertex)
    fold_paths = fold(vertex, []) {|accum, vertex| accum + [vertex]}

    lambda do |init, &proc|
      result_cache = {[] => init}
      current_result = nil
      results = fold_paths.map do |path|
        for i in 1..path.length
          previous_path = path.take (i - 1)
          previous_result = result_cache[previous_path]

          current_path = path.take i
          current_result = result_cache[current_path]
          current_vertex = path[i - 1]

          if current_result.nil?
            current_result = proc.call previous_result, current_vertex
            result_cache[current_path] = current_result
          end
        end
        current_result
      end

      results.to_set
    end
  end

  # Fold right is the fundamental tree recursion operator. Starting with the leaves, it folds up the tree to the given vertex using the given proc. This method works on both cyclic and acyclic graphs.
  #
  # @author Joshua B. Griffith
  # @param [Object] vertex the starting vertex whose descendants will be folded
  # @param [Object] init initial value used for accum
  # @yield [accum, vertex] Block used to combine a vertex with a previously accumulated value
  # @yieldparam [Object] accum previously accumulated value, or init for a leaf vertex. This parameter's type will either be a Set or equal to the type of the init object.
  # @yieldparam [Object] vertex the current vertex
  # @yieldreturn [Object] newly accumulated value
  # @return [Object] the accumulated value at the given vertex
  
  def fold_right(vertex, init, &proc)
    get_targets = lambda do |vertex|
      targets = []
      each_adjacent(vertex) {|v| targets << v}
    end

    vcache = { }
    tree_fold = lambda do |v, visited_vertices|
      targets = get_targets.call v
      if vcache.include? v
        vcache[v]
      elsif targets.empty?
        vcache[v] = proc.call init, v
      else
        filtered = targets - visited_vertices
        folded = filtered.map { |new_v| tree_fold.call new_v, visited_vertices + [v] }
        vcache[v] = proc.call folded.to_set, v
      end
    end

    tree_fold.call(vertex, Set.new)
  end

  # Returns a lambda which, when called with an initial value and a fold_right block, folds up the tree to the given vertex using the given proc, starting with the leaves. This method works on both cyclic and acyclic graphs.
  #
  # @author Joshua B. Griffith
  # @param [Object] vertex the starting vertex whose descendants will be folded
  # @return [Proc] a lambda which, when called given an initial value and a fold_right block, returns the accumulated value at the given vertex
  # @note The returned lambda does not reference the graph when called. The graph is precompiled into the function.
  
  def compile_fold_right(vertex)
    instructions = []
    fold_tree = fold_right vertex, Set.new do |accum, vertex|
      result = (accum + [vertex]).hash
      instructions << { :accum => accum, :vertex => vertex, :result => result }
      result
    end

    lambda do |init, &proc|
      vcache = { }
      instructions.each do |instruction|
        accum = instruction[:accum]
        vertex = instruction[:vertex]
        result = instruction[:result]

        if !vcache.include? result
          if accum.empty?
            vcache[result] = proc.call init, vertex
          else
            new_accum = accum.map do |v|
              vcache[v]
            end
            vcache[result] = proc.call new_accum.to_set, vertex
          end
        end
      end

      vcache[instructions.last[:result]]
    end
  end

  # Returns a set of all paths between the source and target vertices.
  #
  # @author Joshua B. Griffith
  # @param [Object] source starting vertex
  # @param [Object] target ending vertex
  # @return [Set] a set containing all of the paths between the source and target vertices, where each path is represented as an Array
  # @note This method works for both cyclic and acyclic graphs
  def find_all_paths(source, target)
    paths = Set.new
    self.fold source, [] do |accum, vertex|
      last = accum.last
      if last == vertex
        current_path = accum
      else
        current_path = accum + [vertex]
      end
      
      if vertex == target
        len = accum.length
        if len > 1
          paths.add current_path
        elsif len == 1
          paths.add accum + [vertex]
        end
      end
      paths.add current_path if vertex == target && current_path.length > 1
      current_path
    end
    paths
  end
end
