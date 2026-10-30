Rails.application.configure do
  console do
    require('active_record/fixtures')
    require('irb')

    module FixtureConsoleHelpers
      FIXTURE_ROOT = Rails.root.join('test/fixtures')
      HELPER_CALL = /(?<helper>\w+)\([^()]*\z/

      module_function

      def fixture_names
        Dir.glob(FIXTURE_ROOT.join('**/*.yml')).filter_map do |path|
          relative_path = Pathname(path).relative_path_from(FIXTURE_ROOT).to_s
          next if relative_path.start_with?('files/')

          relative_path.delete_suffix('.yml')
        end
      end

      def helper_name_for(fixture_name)
        fixture_name.tr('/', '_')
      end

      def model_class_for(fixture_name)
        fixture_name.classify.constantize
      rescue NameError
        nil
      end

      def primary_key_type_for(model_class)
        model_class.type_for_attribute(model_class.primary_key).type
      end

      def lookup(model_class, label)
        id = ActiveRecord::FixtureSet.identify(label, primary_key_type_for(model_class))
        model_class.unscoped.find(id)
      end

      def labels_for(fixture_name)
        @labels_by_fixture_name ||= {}
        @labels_by_fixture_name[fixture_name] ||=
          ActiveRecord::FixtureSet::File.open(FIXTURE_ROOT.join("#{fixture_name}.yml")) do |file|
            file.map(&:first) - Array(file.ignored_fixtures) - ['DEFAULTS']
          end
      end

      def label_for(model_class, id)
        labels_by_table_and_id[[model_class.table_name, id]]
      end

      def labels_by_table_and_id
        @labels_by_table_and_id ||= fixture_names.flat_map { |fixture_name| label_entries_for(fixture_name) }.to_h
      end

      def label_entries_for(fixture_name)
        model_class = model_class_for(fixture_name)
        return [] unless model_class

        labels_for(fixture_name).map do |label|
          id = ActiveRecord::FixtureSet.identify(label, primary_key_type_for(model_class))
          [[model_class.table_name, id], label.to_sym]
        end
      end

      def fixture_name_for(helper_name)
        @fixture_names_by_helper_name ||= fixture_names.index_by { |fixture_name| helper_name_for(fixture_name) }
        @fixture_names_by_helper_name[helper_name]
      end

      def label_candidates(preposing, target)
        return [] unless target.start_with?(':')

        labels_for_helper_call(preposing).select { |label| label.start_with?(target) }
      end

      def labels_for_helper_call(preposing)
        helper_name = HELPER_CALL.match(preposing)&.[](:helper)
        fixture_name = helper_name && fixture_name_for(helper_name)
        return [] unless fixture_name

        labels_for(fixture_name).map { |label| ":#{label}" }
      end
    end

    module FixtureLabelCompletion
      def completion_candidates(preposing, target, postposing, bind:)
        candidates = FixtureConsoleHelpers.label_candidates(preposing, target)
        candidates.any? ? candidates : super
      end
    end

    [IRB::RegexpCompletor, IRB::TypeCompletor].each { |completor| completor.prepend(FixtureLabelCompletion) }

    ActiveSupport.on_load(:active_record) do
      def fixture_name
        FixtureConsoleHelpers.label_for(self.class, id)
      end
    end

    fixture_helpers = Module.new do
      FixtureConsoleHelpers.fixture_names.each do |fixture_name|
        model_class = FixtureConsoleHelpers.model_class_for(fixture_name)
        next unless model_class

        define_method(FixtureConsoleHelpers.helper_name_for(fixture_name)) do |*labels|
          records = labels.map do |label|
            FixtureConsoleHelpers.lookup(model_class, label.to_sym)
          rescue ActiveRecord::RecordNotFound
            raise(
              ActiveRecord::RecordNotFound,
              "#{model_class.name} fixture #{label.inspect} was not found in the current #{Rails.env} database"
            )
          end

          labels.one? ? records.first : records
        end
      end
    end

    TOPLEVEL_BINDING.eval('self').extend(fixture_helpers)
  end
end
