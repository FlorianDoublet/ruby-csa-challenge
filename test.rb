#!/usr/bin/env ruby

require 'test/unit'

if ARGV.size != 1
  puts "Usage: ruby #{$0} routing_executable"
  exit(-1)
end

EXECUTABLE = ARGV[0]

class TestCSA < Test::Unit::TestCase

  TIMETABLE =<<EOF
1 3 2000 10000
1 2 3600 7200
1 2 3900 7200
2 3 4000 5000
1 5 4500 7000
1 3 4600 6000
1 3 5000 6000
3 4 6500 7000
3 4 6700 7000
3 2 7000 8000
3 2 7000 9000
2 5 8100 8600
2 3 8000 9000

EOF

  def setup
    @io = IO.popen EXECUTABLE, "r+"

    @io.write TIMETABLE
  end

  def teardown
    @io.write "\n"
    @io.close
  end

  def read_answer(io)
    result = []
    line = io.gets.strip
    if line != "NO_SOLUTION"
      while !line.empty?
        tokens = line.split " "
        result << {
          :departure_station => tokens[0].to_i,
          :arrival_station => tokens[1].to_i,
          :departure_timestamp => tokens[2].to_i,
          :arrival_timestamp => tokens[3].to_i,
        }

        line = io.gets.strip
      end
    end

    result
  end

  def test_simple_route
    @io.puts "3 2 6000"
    response = read_answer @io
    assert_equal 1, response.size
    assert_equal 3, response[0][:departure_station]
    assert_equal 2, response[0][:arrival_station]
    assert_equal 7000, response[0][:departure_timestamp]
    assert_equal 8000, response[0][:arrival_timestamp]
  end

  def test_route_with_connection
    @io.puts "3 5 6000"
    response = read_answer @io
    assert_equal 2, response.size
    assert_equal 3, response[0][:departure_station]
    assert_equal 2, response[0][:arrival_station]
    assert_equal 8000, response[0][:arrival_timestamp]
    assert_equal 2, response[1][:departure_station]
    assert_equal 5, response[1][:arrival_station]
    assert_equal 8600, response[1][:arrival_timestamp]
  end


  def test_simple_route_later_departure
    @io.puts "1 2 3000"
    response = read_answer @io
    assert_equal 1, response.size
    assert_equal 1, response[0][:departure_station]
    assert_equal 2, response[0][:arrival_station]
    # the departure could be 3600 to arrive at 7200
    # but the later departure to arrive at 7200 is 3900
    assert_equal 3900, response[0][:departure_timestamp]
    assert_equal 7200, response[0][:arrival_timestamp]
  end

  def test_route_with_connection_later_departure
    @io.puts "1 4 3000"
    response = read_answer @io
    assert_equal 2, response.size
    # the first connection
    assert_equal 1, response[0][:departure_station]
    assert_equal 3, response[0][:arrival_station]
    # the departure could be 4600 here to arrival at the same station to the same hour
    assert_equal 5000, response[0][:departure_timestamp]
    assert_equal 6000, response[0][:arrival_timestamp]
    # the second one
    assert_equal 3, response[1][:departure_station]
    assert_equal 4, response[1][:arrival_station]
    # it also work for middle transit, we could departure from the station 3 to 4 at 6500 to arrival at 7000 too
    # instead we take the connection from 3 to 4 at 6700
    assert_equal 6700, response[1][:departure_timestamp]
    assert_equal 7000, response[1][:arrival_timestamp]
  end

  def test_invalid_station
    @io.puts "5 3 4000"
    response = read_answer @io
    assert_equal 0, response.size
  end

  def test_multiple_queries
    @io.puts "1 3 4000"
    response1 = read_answer @io
    @io.puts "1 3 4000"
    response2 = read_answer @io

    assert_equal 1, response1.size
    assert_equal 1, response2.size
  end

end
