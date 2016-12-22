#!/usr/bin/env ruby

MAX_STATIONS = 100000
INF = 1.0/0

class Connection
  attr_reader :departure_station, :arrival_station,
              :departure_timestamp, :arrival_timestamp

  def initialize(line)
    tokens = line.split(" ")

    @departure_station    = tokens[0].to_i
    @arrival_station      = tokens[1].to_i
    @departure_timestamp  = tokens[2].to_i
    @arrival_timestamp    = tokens[3].to_i
  end
end

class Timetable
  attr_reader :connections

  # reads all the connections from stdin
  def initialize
    @connections = []
    line = STDIN.gets.strip

    while !line.empty?
      @connections << Connection.new(line)
      line = STDIN.gets.strip
    end
  end
end

class CSA
  attr_reader :timetable, :in_connection, :earliest_arrival, :arrival_station, :min_number_connections, :earliest_value, :route_with_least_connection
  # for the least connections problem
  attr_reader :arrival_station
  attr_accessor :min_number_connections, :earliest_value, :route_with_least_connection

  def initialize
    @timetable = Timetable.new
    @min_number_connections = INF
    @earliest_value = INF
    @route_with_least_connection = Array.new
  end

  def main_loop(arrival_station)
    earliest = INF
    timetable.connections.each_with_index do |c, i|
      if c.departure_timestamp >= earliest_arrival[c.departure_station] && c.arrival_timestamp < earliest_arrival[c.arrival_station]
        earliest_arrival[c.arrival_station] = c.arrival_timestamp
        in_connection[c.arrival_station] = i
        if c.arrival_station == arrival_station
          earliest = [earliest, c.arrival_timestamp].min
        end
      elsif c.arrival_timestamp > earliest
        return
      end
    end
  end

  def print_route(route)
    if route.empty? then puts "NO_SOLUTION"
    else
      route.each do |c|
        puts "#{c.departure_station} #{c.arrival_station} #{c.departure_timestamp} #{c.arrival_timestamp}"
      end
    end
    puts ""
    STDOUT.flush
  end

  def print_result(arrival_station)
    if in_connection[arrival_station] == INF
      puts "NO_SOLUTION"
    else
      route = []
      # We have to rebuild the route from the arrival station
      last_connection_index = in_connection[arrival_station]
      while last_connection_index != INF
        connection = timetable.connections[last_connection_index]
        route << connection
        last_connection_index = in_connection[connection.departure_station]
      end

      # And now print it out in the right direction
      route.reverse.each do |c|
        puts "#{c.departure_station} #{c.arrival_station} #{c.departure_timestamp} #{c.arrival_timestamp}"
      end
    end
    puts ""
    STDOUT.flush
  end

  def compute(departure_station, arrival_station, departure_time)
    @in_connection = {}
    @earliest_arrival = {}

    MAX_STATIONS.times do |i|
      in_connection[i] = INF
      earliest_arrival[i] = INF
    end

    earliest_arrival[departure_station] = departure_time;

    if departure_station <= MAX_STATIONS && arrival_station <= MAX_STATIONS
      main_loop(arrival_station)
    end

    print_result(arrival_station)
  end

  # Compute and print the solution with the least connection
  def compute_least_connection_route(departure_station, arrival_station, departure_time)
    final_list = Array.new
    # init our arrival station
    @arrival_station = arrival_station
    # launch our process to find the shortest route
    permute(timetable.connections, final_list, departure_station, departure_time)
    # print the solution
    print_route(route_with_least_connection)
  end


  # Semi-recursive method to compute all the possible route solution
  # potentially very costly but optimized to only compute potential minimum route solution and not all the possible route
  def permute(to_permute, final_list, station, timestamp)
    # here we know that our final list contain a route which start from the departure station and
    # arrive to the arrival station
    if not final_list.empty? and final_list.last.arrival_station == arrival_station
      if final_list.size < @min_number_connections
        @min_number_connections = final_list.size-1
        @earliest_value = final_list.last.arrival_timestamp
        # save our solution
        @route_with_least_connection = final_list
      else
        # it means the the route as the same number of connection than the previous solution
        compute_best_minimum_route(final_list)
      end
      return
    end

    # here we save memory and calculus in removing all the connection with a later departure than our timestamp
    if final_list.size > @min_number_connections then return end

    to_permute.delete_if { |connection| connection.departure_timestamp < timestamp }

    to_permute.each_with_index do |connection, i|
      # if the departure station of the scanned connection isn't the arrival of the previous one we don't have to compute for solutions
      if connection.departure_station != station then next end

      # create copy of arrays
      final_cpy = final_list.dup
      to_perm_cpy = to_permute.dup
      # remove a scanned connection into the permutation copy list, to add it into the final copy list
      final_cpy.push(to_perm_cpy.delete_at(i))
      # permute with the copies and the new information to the latest added connection into the final copy list
      permute(to_perm_cpy, final_cpy, final_cpy.last.arrival_station, final_cpy.last.arrival_timestamp)

    end
  end

  # test if the concurrent route is better than the existing best one
  # and if it is replace the older route by the concurrent
  def compute_best_minimum_route(concurrent_route)
    # the first most important parameter is the arrival time
    if concurrent_route.last.arrival_timestamp < @earliest_value
      @earliest_value = concurrent_route.last.arrival_timestamp
      @route_with_least_connection = concurrent_route
    elsif concurrent_route.first.departure_timestamp > @route_with_least_connection.first.departure_timestamp
      # here the arrival time is the same, but we can still leave later
      @route_with_least_connection = concurrent_route
    else
      # if the departure time and the arrival time is the same, we gonna compute the best by the smallest travel time
      # it's the less important priority for the best route
      val_concurrent = 0
      val_solution = 0
      concurrent_route.each_index do |i|
        val_concurrent += concurrent_route[i].arrival_timestamp - concurrent_route[i].departure_timestamp
        val_solution += @route_with_least_connection[i].arrival_timestamp - @route_with_least_connection[i].departure_timestamp
      end
      # then update the solution if the concurrent is better
      if val_concurrent < val_solution then @route_with_least_connection = concurrent_route end
    end
  end


end

def main
  csa = CSA.new

  line = STDIN.gets.strip

  while !line.empty?
    tokens = line.split(" ")
    csa.compute_least_connection_route(tokens[0].to_i, tokens[1].to_i, tokens[2].to_i)
    line = STDIN.gets.strip
  end
end

main
