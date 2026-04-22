module PerfectCX
  module Plans
    CONFIG_PATH = Rails.root.join('config', 'perfectcx_plans.yml')
    FEATURES_PATH = Rails.root.join('config', 'features.yml')
    ALL_FEATURES_TOKEN = 'ALL'.freeze

    class << self
      def all
        @all ||= YAML.safe_load_file(CONFIG_PATH).freeze
      end

      def names
        all.keys
      end

      def exists?(name)
        all.key?(name.to_s)
      end

      # Returns a normalized hash for the plan with `features` expanded
      # (ALL → every non-deprecated, non-internal feature name).
      def find(name)
        raw = all[name.to_s]
        return nil if raw.nil?

        raw.merge('features' => expand_features(raw['features']))
      end

      # Every feature name eligible for plan assignment.
      def all_feature_names
        @all_feature_names ||= YAML.safe_load_file(FEATURES_PATH)
                                   .reject { |f| f['deprecated'] || f['chatwoot_internal'] }
                                   .map { |f| f['name'] }
                                   .freeze
      end

      def reset_cache!
        @all = nil
        @all_feature_names = nil
      end

      private

      def expand_features(features)
        return all_feature_names if features == ALL_FEATURES_TOKEN

        Array(features)
      end
    end
  end
end
