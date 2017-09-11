module BlocRecord
   def self.connect_to(filename)
     @database_filename = filename
     @database = database
   end

   def self.database_filename
     @database_filename
   end

   def self.database
     @database
   end
 end
