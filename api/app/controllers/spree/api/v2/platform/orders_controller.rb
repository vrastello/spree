module Spree
  module Api
    module V2
      module Platform
        class OrdersController < ResourceController
          include Spree::Api::V2::Platform::OrderConcern

          ORDER_WRITE_ACTIONS = %i[create update destroy advance next add_item complete
                                   remove_line_item set_quantity approve empty apply_coupon_code remove_coupon_code]

          before_action -> { doorkeeper_authorize! :write, :admin }, only: ORDER_WRITE_ACTIONS

          def create
            spree_authorize! :create, Spree::Order
            set_order_currency
            load_user

            order_params = {
              user: @user,
              store: current_store,
              currency: @currency
            }

            order = create_service.call(order_params).value

            render_serialized_payload(201) { serialize_resource(order) }
          end

          def add_item
            spree_authorize! :update, spree_order
            spree_authorize! :show, @variant
            load_variant

            result = add_item_service.call(
              order: spree_order,
              variant: @variant,
              quantity: params[:quantity],
              options: params[:options]
            )

            render_order(result)
          end

          def remove_line_item
            spree_authorize! :update, spree_order

            result = remove_line_item_service.call(
              order: spree_order,
              line_item: line_item
            )

            render_order(result)
          end

          def set_quantity
            return render_error_item_quantity unless params[:quantity].to_i > 0

            spree_authorize! :update, spree_order

            result = set_item_quantity_service.call(order: spree_order, line_item: line_item, quantity: params[:quantity])

            render_order(result)
          end

          def next
            spree_authorize! :update, spree_order

            result = next_service.call(order: spree_order)

            render_order(result)
          end

          def advance
            spree_authorize! :update, spree_order

            result = advance_service.call(order: spree_order)

            render_order(result)
          end

          def complete
            spree_authorize! :update, spree_order

            result = complete_service.call(order: spree_order)

            render_order(result)
          end

          def approve
            spree_authorize! :update, spree_order
            spree_order.approved_by(spree_current_user)

            render_serialized_payload { serialize_resource(spree_order) }
          end

          def empty
            spree_authorize! :update, spree_order

            spree_order.empty!

            render_serialized_payload { serialize_resource(spree_order) }
          end

          def update
            spree_authorize! :update, spree_order

            result = update_service.call(
              order: spree_order,
              params: params,
              # defined in https://github.com/spree/spree/blob/master/core/lib/spree/core/controller_helpers/strong_parameters.rb#L19
              permitted_attributes: permitted_checkout_attributes,
              request_env: request.headers.env
            )

            render_order(result)
          end

          def apply_coupon_code
            spree_authorize! :update, spree_order

            spree_order.coupon_code = params[:coupon_code]
            result = coupon_handler.new(spree_order).apply

            if result.error.blank?
              render_serialized_payload { serialize_resource(spree_order) }
            else
              render_error_payload(result.error)
            end
          end

          def remove_coupon_code
            spree_authorize! :update, spree_order

            coupon_codes = select_coupon_codes

            return render_error_payload(Spree.t('v2.cart.no_coupon_code', scope: 'api')) if coupon_codes.empty?

            result_errors = coupon_codes.count > 1 ? select_errors(coupon_codes) : select_error(coupon_codes)

            if result_errors.blank?
              render_serialized_payload { serialize_resource(spree_order) }
            else
              render_error_payload(result_errors)
            end
          end

          protected

          def resource
            @resource ||= spree_order
          end

          private

          def model_class
            Spree::Order
          end

          def scope_includes
            [:line_items]
          end

          def create_service
            Spree::Api::Dependencies.platform_order_create_service.constantize
          end

          def add_item_service
            Spree::Api::Dependencies.platform_order_add_item_service.constantize
          end

          def remove_line_item_service
            Spree::Api::Dependencies.platform_order_remove_line_item_service.constantize
          end

          def next_service
            Spree::Api::Dependencies.platform_order_next_service.constantize
          end

          def advance_service
            Spree::Api::Dependencies.platform_order_advance_service.constantize
          end

          def complete_service
            Spree::Api::Dependencies.platform_order_complete_service.constantize
          end

          def update_service
            Spree::Api::Dependencies.platform_order_update_service.constantize
          end

          def set_item_quantity_service
            Spree::Api::Dependencies.platform_order_set_item_quantity_service.constantize
          end

          def coupon_handler
            Spree::Api::Dependencies.platform_coupon_handler.constantize
          end
        end
      end
    end
  end
end
