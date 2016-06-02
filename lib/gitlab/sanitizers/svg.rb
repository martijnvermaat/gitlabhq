module Gitlab
  module Sanitizers
    module SVG
      def self.clean(data)
        Loofah.xml_document(data).scrub!(Scrubber.new).to_s
      end

      class Scrubber < Loofah::Scrubber
        # http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#embedding-custom-non-visible-data-with-the-data-*-attributes
        DATA_ATTR_PATTERN = /\Adata-(?!xml)[a-z_][\w.\u00E0-\u00F6\u00F8-\u017F\u01DD-\u02AF-]*\z/u

        def scrub(node)
          unless Whitelist::ALLOWED_ELEMENTS.include?(node.name)
            node.unlink
          else
            valid_attributes = Whitelist::ALLOWED_ATTRIBUTES[node.name]

            node.attribute_nodes.each do |attr|
              unless valid_attributes && valid_attributes.include?(attribute_name_with_namespace(attr))
                if Whitelist::ALLOWED_DATA_ATTRIBUTES_IN_ELEMENTS.include?(node.name) && data_attribute?(attr)
                  # Arbitrary data attributes are allowed. Verify that the attribute
                  # is a valid data attribute.
                  attr.unlink unless attr_name =~ DATA_ATTR_PATTERN
                else
                  attr.unlink
                end
              end
            end
          end
        end

        def attribute_name_with_namespace(attr)
          if attr.namespace
            "#{attr.namespace.prefix}:#{attr.name}"
          else
            attr.name
          end
        end

        private

        def data_attribute?(attr)
          attr.name.start_with?('data-')
        end
      end
    end
  end
end
