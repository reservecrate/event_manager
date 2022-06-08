require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def sanitize_phone_number(phone_number)
  sanitized_phone_number = phone_number.gsub(/[-,.()\s]/, '')
  if sanitized_phone_number.size == 11 and sanitized_phone_number[0] == '1'
    sanitized_phone_number = sanitized_phone_number[1..-1]
  elsif (sanitized_phone_number.size == 11 and sanitized_phone_number[0] != '1') or sanitized_phone_number.size != 10
    return sanitized_phone_number = '(000) 000-0000'
  end
  "(#{sanitized_phone_number[0..2]}) #{sanitized_phone_number[3..5]}-#{sanitized_phone_number[6..-1]}"
end

def create_datetime_obj str
  Time.strptime(str, '%m/%d/%y %H:%M')
end

def time_targeting times
  peak_registration_hours = []
  times_tally = times.map { |time| time.hour }.tally
  until peak_registration_hours.size == 3
    max_value_pair = times_tally.max_by { |k, v| v }
    peak_registration_hours << max_value_pair
    times_tally.delete(max_value_pair[0])
  end
  "Peak registration hours:\n#{peak_registration_hours[0][0]}:00 -> #{peak_registration_hours[0][1]}\n#{peak_registration_hours[1][0]}:00 -> #{peak_registration_hours[1][1]}\n#{peak_registration_hours[2][0]}:00 -> #{peak_registration_hours[2][1]}"
end

def day_of_the_week_targeting datetimes
  peak_registration_days = []
  days_of_the_week_tally = datetimes.map { |datetime| Date::DAYNAMES.rotate(1)[datetime.wday] }.tally
  until peak_registration_days.size == 3
    max_value_pair = days_of_the_week_tally.max_by { |k, v| v }
    peak_registration_days << max_value_pair
    days_of_the_week_tally.delete(max_value_pair[0])
  end
  "Peak registration days:\n#{peak_registration_days[0][0]} -> #{peak_registration_days[0][1]}\n#{peak_registration_days[1][0]} -> #{peak_registration_days[1][1]}\n#{peak_registration_days[2][0]} -> #{peak_registration_days[2][1]}"
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
    filename = "output/thanks_#{id}.html"
    File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

times = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = sanitize_phone_number(row[5])
  time_s = row[1]
  times << create_datetime_obj(time_s)
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

puts time_targeting(times)
puts day_of_the_week_targeting(times)
