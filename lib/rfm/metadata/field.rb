module Rfm
  module Metadata
  
    # The Field object represents a single FileMaker field. It *does not hold the data* in the field. Instead,
    # it serves as a source of metadata about the field. For example, if you're script is trying to be highly
    # dynamic about its field access, it may need to determine the data type of a field at run time. Here's
    # how:
    #
    #   field_name = "Some Field Name"
    #   case myRecord.fields[field_name].result
    #   when "text"
    #     # it is a text field, so handle appropriately
    #   when "number"
    #     # it is a number field, so handle appropriately
    #   end
    #
    # =Attributes
    #
    # The Field object has the following attributes:
    #
    # * *name* is the name of the field
    #
    # * *result* is the data type of the field; possible values include:
    #   * text
    #   * number
    #   * date
    #   * time
    #   * timestamp
    #   * container
    #
    # * *type* any of these:
    #   * normal (a normal data field)
    #   * calculation
    #   * summary
    #
    # * *max_repeats* is the number of repetitions (1 for a normal field, more for a repeating field)
    #
    # * *global* is +true+ is this is a global field, *false* otherwise
    #
    # Note: Field types match FileMaker's own values, but the terminology differs. The +result+ attribute
    # tells you the data type of the field, regardless of whether it is a calculation, summary, or normal
    # field. So a calculation field whose result type is _timestamp_ would have these attributes:
    #
    # * result: timestamp
    # * type: calculation
    #
    # * *control& is a FieldControl object representing the sytle and value list information associated
    #   with this field on the layout.
    # 
    # Note: Since a field can sometimes appear on a layout more than once, +control+ may be an Array.
    # If you don't know ahead of time, you'll need to deal with this. One easy way is:
    #
    #   controls = [myField.control].flatten
    #   controls.each {|control|
    #     # do something with the control here
    #   }
    #
    # The code above makes sure the control is always an array. Typically, though, you'll know up front
    # if the control is an array or not, and you can code accordingly.
    class Field
      
      attr_reader :name, :result, :type, :max_repeats, :global
      meta_attr_accessor :resultset
      # Initializes a field object. You'll never need to do this. Instead, get your Field objects from
      # Resultset::field_meta
			def initialize(attributes)
				_attach_as_instance_variables attributes
				self
			end
    
      # Coerces the text value from an +fmresultset+ document into proper Ruby types based on the 
      # type of the field. You'll never need to do this: Rfm does it automatically for you when you
      # access field data through the Record object.
      def coerce(value)
        return nil if (value.nil? or value.empty?)
        case result
        when "text"      then value
        when "number"    then BigDecimal.new(value.to_s)
        when "date"      then Date.strptime(value, resultset.date_format)
        when "time"      then DateTime.strptime("1/1/-4712 #{value}", "%m/%d/%Y #{resultset.time_format}")
        when "timestamp" then DateTime.strptime(value, resultset.timestamp_format)
        when "container" then
        	resultset_meta = resultset.instance_variable_get(:@meta)
        	if resultset_meta && resultset_meta['doctype'] && value.to_s[/\?/]
        		URI.parse(resultset_meta['doctype'].last.to_s).tap{|uri| uri.path, uri.query = value.split('?')}
        	else
        		value
        	end
        else nil
        end
#       rescue
#         puts("ERROR in Field#coerce:", name, value, result, $!)
#         nil
      end
      
      def get_mapped_name
      	(resultset && resultset.layout && resultset.layout.field_mapping[name]) || name
      end
            
			def main_callback(cursor)
				self.resultset = cursor.top.object
				resultset.field_meta[get_mapped_name.to_s.downcase] = self
			end
			
			def portal_callback(cursor)
				self.resultset = cursor.top.object
				cursor.parent.object[get_mapped_name.split('::').last.to_s.downcase] = self
				#puts ['FIELD_portal_callback', name, cursor.parent.object.object_id, cursor.parent.tag, cursor.parent.object[name.split('::').last.to_s.downcase]].join(', ')
			end
      
    end # Field
  end # Metadata
end # Rfm