require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(phone_number)
  cleaned_num = phone_number.gsub(/[^0-9]/, '')
  case cleaned_num.length
  when 10
    cleaned_num
  when 11
    if cleaned_num.start_with?('1')
      cleaned_num[1..]
    else
      "bad"
    end
  else
    "bad"
  end
end

def parse_registration_date(registration_date)
  format = '%m/%d/%y %H:%M'
  parsed_registration_datetime = DateTime.strptime(registration_date, format)
  parsed_registration_dates << parsed_registration_datetime
  return parsed_registration_datetime
end

def registered_hours(datetimes_array)
  registered_hours = Hash.new(0)
  datetimes_array.each do |datetime|
    registered_hours[datetime.hour] += 1
  end
  registered_hours
end

def find_peak_hour(registered_hours)
  max_registrations = registered_hours.values.max
  peak_hours = registered_hours.select {|hour,count| count == max_registrations}.keys
  peak_hours
end

def registered_days(datetimes_array)
  registered_days = Hash.new(0)

  datetimes_array.each do |datetime|
    registered_days[datetime.wday] += 1
  end
  registered_days
end

def find_peak_days(registered_days)
  day_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
  max_day = registered_days.values.max
  peak_days = registered_days.select {|day,count| count == max_day}.keys
  peak_days_names = peak_days.map {|day| day_names[day]}
  peak_days_names
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

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter
parsed_registration_dates = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  registration_date = parse_registration_date(row[:regdate])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

registered_hours = registered_hours(parsed_registration_dates)
peak_hours = find_peak_hour(registered_hours)
puts "Peak registration hours: #{peak_hours.join(', ')}"
registered_days = registered_days(parsed_registration_dates)
peak_days = find_peak_days(registered_days)
puts "Peak registration days: #{peak_days.join(', ')}"
