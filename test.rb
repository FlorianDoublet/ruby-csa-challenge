#!/usr/bin/env ruby

require 'test/unit'

if ARGV.size != 1
  puts "Usage: ruby #{$0} routing_executable"
  exit(-1)
end

EXECUTABLE = ARGV[0]

class TestCSA < Test::Unit::TestCase

  TIMETABLE =<<EOF
1 2 2000 3000
2 3 3000 7000
1 2 4000 7200
1 3 4500 6000
1 3 5000 6000
3 4 6000 6200
4 5 6300 7000
3 2 6500 7000
3 2 6700 7000
3 5 7500 9000
2 5 8000 9000

EOF

  def setup
    @io = IO.popen EXECUTABLE, "r+"

    @io.write TIMETABLE
  end

  def setup_personal_timetable(personal_timetable)
    @io = IO.popen EXECUTABLE, "r+"

    @io.write personal_timetable
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
    @io.puts "1 2 1000"
    response = read_answer @io
    assert_equal 1, response.size
    assert_equal 1, response[0][:departure_station]
    assert_equal 2, response[0][:arrival_station]
    assert_equal 2000, response[0][:departure_timestamp]
    assert_equal 3000, response[0][:arrival_timestamp]
  end

  def test_route_with_connection
    @io.puts "1 4 3000"
    response = read_answer @io
    assert_equal 2, response.size
    assert_equal 1, response[0][:departure_station]
    assert_equal 3, response[0][:arrival_station]
    assert_equal 6000, response[0][:arrival_timestamp]
    assert_equal 3, response[1][:departure_station]
    assert_equal 4, response[1][:arrival_station]
    assert_equal 6200, response[1][:arrival_timestamp]
  end


  def test_least_connection_route
    @io.puts "2 5 3000"
    response = read_answer @io
    assert_equal 1, response.size
    assert_equal 2, response[0][:departure_station]
    assert_equal 5, response[0][:arrival_station]
    # we could arrive earlier with the path 2 -> 3 / 3 -> 5 but there is more connection than 2 -> 5
    assert_equal 8000, response[0][:departure_timestamp]
    assert_equal 9000, response[0][:arrival_timestamp]
  end

  def test_earliest_minimum_route

    teardown
    personal_timetable = <<EOF
1 2 2000 3000
2 5 3500 5000
1 2 4000 7200
2 5 8000 9000

EOF
    setup_personal_timetable(personal_timetable)

    @io.puts "1 5 2000"
    response = read_answer @io
    assert_equal 2, response.size
    assert_equal 1, response[0][:departure_station]
    assert_equal 2, response[0][:arrival_station]
    assert_equal 2000, response[0][:departure_timestamp]
    assert_equal 2, response[1][:departure_station]
    assert_equal 5, response[1][:arrival_station]
    assert_equal 5000, response[1][:arrival_timestamp]
  end

  def test_minimum_route_with_the_latest_departure

    teardown
    personal_timetable = <<EOF
1 2 2000 3000
1 2 4000 7200
2 5 8000 9000

EOF
    setup_personal_timetable(personal_timetable)

    @io.puts "1 5 2000"
    response = read_answer @io
    assert_equal 2, response.size
    assert_equal 1, response[0][:departure_station]
    assert_equal 2, response[0][:arrival_station]
    # the earliest departure is 1 2 2000 3000 but we don't want it
    assert_equal 4000, response[0][:departure_timestamp]
    assert_equal 2, response[1][:departure_station]
    assert_equal 5, response[1][:arrival_station]
    assert_equal 9000, response[1][:arrival_timestamp]
  end

  def test_the_more_confortable_route_with_equals_departure_and_arrival
    teardown
    personal_timetable = <<EOF
1 4 2000 3000
1 2 2000 6000
4 3 5000 6000
2 3 6000 7000
3 5 8000 9000

EOF
    setup_personal_timetable(personal_timetable)

    @io.puts "1 5 2000"
    response = read_answer @io
    assert_equal 3, response.size
    # first connection
    assert_equal 1, response[0][:departure_station]
    assert_equal 4, response[0][:arrival_station]
    assert_equal 2000, response[0][:departure_timestamp]
    assert_equal 3000, response[0][:arrival_timestamp]
    # second connection
    assert_equal 4, response[1][:departure_station]
    assert_equal 3, response[1][:arrival_station]
    assert_equal 5000, response[1][:departure_timestamp]
    assert_equal 6000, response[1][:arrival_timestamp]
    # the third connection
    assert_equal 3, response[2][:departure_station]
    assert_equal 5, response[2][:arrival_station]
    assert_equal 8000, response[2][:departure_timestamp]
    assert_equal 9000, response[2][:arrival_timestamp]
    # a less confortable route but with the same depature and arrival timestamp could be
    # 1 2 2000 6000
    # 2 3 6000 7000
    # 3 5 8000 9000
    # because the trip time IN vehicle is longer
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
