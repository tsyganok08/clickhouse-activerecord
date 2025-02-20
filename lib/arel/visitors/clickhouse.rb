require 'arel/visitors/to_sql'

module Arel
  module Visitors
    class Clickhouse < ::Arel::Visitors::ToSql

      def aggregate(name, o, collector)
        # replacing function name for materialized view
        if o.expressions.first && o.expressions.first != '*' && !o.expressions.first.is_a?(String) && o.expressions.first.relation&.is_view
          super("#{name.downcase}Merge", o, collector)
        else
          super
        end
      end

      def visit_Arel_Table o, collector
        if o.table_alias
          collector << "#{quote_table_name o.name} #{quote_table_name o.table_alias}"
        else
          collector << quote_table_name(o.name)
        end
        collector << ' FINAL ' if o.final
        collector
      end

      def visit_Arel_Nodes_SelectOptions(o, collector)
        maybe_visit o.settings, super
      end

      def visit_Arel_Nodes_Final(o, collector)
        collector << " FINAL "
        collector
      end

      def visit_Arel_Nodes_Settings(o, collector)
        return collector if o.expr.empty?

        collector << "SETTINGS "
        o.expr.each_with_index do |(key, value), i|
          collector << ", " if i > 0
          collector << key.to_s.gsub(/\W+/, "")
          collector << " = "
          collector << sanitize_as_setting_value(value)
        end
        collector
      end

      def sanitize_as_setting_value(value)
        if value == :default
          'DEFAULT'
        else
          quote(value)
        end
      end

      def sanitize_as_setting_name(value)
        return value if Arel::Nodes::SqlLiteral === value
        @connection.sanitize_as_setting_name(value)
      end

    end
  end
end
