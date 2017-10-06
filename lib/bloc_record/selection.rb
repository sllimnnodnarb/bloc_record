require 'sqlite3'

module Selection
  def find(*ids)
    if ids.length == 1
      find_one(ids.first)
    else
      ids.each do |id|
        unless id.is_a?(Numeric) && id >= 1
          raise ArgumentError.new("The number you are looking for must be 1 or greater.")
        end
      end
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        WHERE id IN (#{ids.join(",")});
      SQL
      rows_to_array(rows)
    end
  end

  def find_one(id)
    ids.each do |id|
      unless id.is_a?(Numeric) && id >= 1
        raise ArgumentError.new("The number you are looking for must be 1 or greater.")
      end
    end
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE id = #{id};
    SQL
    init_object_from_row(row)
  end

  def find_by(attribute, value)
    if attribute.is_a?(Symbol)
      attribute = attribute.to_s
    end
    unless attribute.is_a?(String)
      raise ArgumentError.new("Please use text only, no symbols.")
    end
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE #{attribute} = #{BlocRecord::Utility.sql_strings(value)};
    SQL
    init_object_from_row(row)
  end

  def find_each(start_size = {})
    start = start_size.has_key?(:start) ? start_size[:start] : 0
    batch_size = start_size.has_key?(:batch_size) ? start_size[:batch_size] : 2000

    rows = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      LIMIT batch_size OFFSET start;
    SQL

    yield(rows_to_array(rows))
  end

  def find_in_batches(start_size = {})
    start = start_size.has_key?(:start) ? start_size[:start] : 0
    batch_size = start_size.has_key?(:batch_size) ? start_size[:batch_size] : 2000

    while  i < batches + 1 do
      rows = connection.get_first_row <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        LIMIT batch_size OFFSET start;
      SQL

      yield(rows_to_array(rows))
    end
  end

  def take(num=1)
    unless num.is_a?(Numeric) && num >= 1
      raise ArgumentError.new("The number must be 1 or greater.")
    end
    if num > 1
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        ORDER BY random()
        LIMIT #{num};
      SQL
      rows_to_array(rows)
    else
      take_one
    end
  end

  def take_one
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY random()
      LIMIT 1;
    SQL
    init_object_from_row(row)
  end

  def first
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id ASC LIMIT 1;
    SQL
    init_object_from_row(row)
  end

  def last
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id DESC LIMIT 1;
    SQL
    init_object_from_row(row)
  end

  def all
    rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table};
    SQL
    rows_to_array(rows)
  end

  def where(*args)
    if args.count > 1
      expression = args.shift
      params = args
    else
      case args.first
      when String
        expression = args.first
      when Hash
        expression_hash = BlocRecord::Utility.convert_keys(args.first)
        expression = expression_hash.map {|key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}"}.join(" and ")
      end
    end

    sql = <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE #{expression};
    SQL

    rows = connection.execute(sql, params)
    rows_to_array(rows)
  end

  def order(*args)
    case args.first
    when string
      if args.count > 1
        order = args.join(",")
      end
    when symbol
      order = args.first.to_s
    when Hash
      expression_hash = BlocRecord::Utility.convert_keys(args.first)
      expression = expression_hash.map {|key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}"}.join(" and ")
    end
    rows = connection.execute <<-SQL
      SELECT * FROM #{table}
      ORDER BY #{order};
    SQL
    rows_to_array(rows)
  end

  def join(*args)
    if args.count > 1
      joins = args.map { |arg| "INNER JOIN #{arg} ON #{arg}.#{table}_id = #{table}.id"}.join(" ")
      rows = connection.execute <<-SQL
        SELECT * FROM #{table} #{joins}
      SQL
    else
      case args.first
      when String
        rows = connection.execute <<-SQL
          SELECT * FROM #{table} #{BlocRecord::Utility.sql_strings(args.first)};
        SQL
      when Symbol
        rows = connection.execute <<-SQL
          SELECT * FROM #{table}
          INNER JOIN #{args.first} ON #{args.first}.#{table}_id = #{table}.id
        SQL
      end
    end
    rows_to_array(rows)
  end

  def method_missing(method, *args, &block)
    puts self.id
    m = method.to_s
    arr = m.split("_")
    if m.start_with?("update_")
      self.class.update(self.id, {arr[-1] => args[0]})
    else
      super
    end
  end

  private

  def init_object_from_row(row)
    if row
      data = Hash[columns.zip(row)]
      new(data)
    end
  end

  def rows_to_array(rows)
    collection = BlocRecord::Collection.new
    rows.each { |row| collection << new(Hash[columns.zip(row)]) }
    collection
  end
end
