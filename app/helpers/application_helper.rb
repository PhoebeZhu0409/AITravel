module ApplicationHelper
  # Short month + day (no year) for agenda day tabs — e.g. "Sept. 29"
  def agenda_brief_date(date)
    month = case date.month
            when 1 then "Jan."
            when 2 then "Feb."
            when 3 then "Mar."
            when 4 then "Apr."
            when 5 then "May"
            when 6 then "June"
            when 7 then "July"
            when 8 then "Aug."
            when 9 then "Sept."
            when 10 then "Oct."
            when 11 then "Nov."
            when 12 then "Dec."
            end
    "#{month} #{date.day}"
  end
end
