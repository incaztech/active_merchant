module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BanwireGateway < Gateway
      URL = 'https://banwire.com/api.pago_pro'
      self.test_url = 'https://banwire.com/qa/api.pago_pro'
      self.live_url = 'https://banwire.com/api.pago_pro'

      self.supported_countries = ['MX']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.banwire.com/'
      self.display_name = 'Banwire'

      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_response_type(post)
        add_customer_data(post, options)
        add_order_data(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_amount(post, money, options)
        add_deviceid(post, options)
        add_merchant_data(post, options)

        commit(money, post)
      end

      private

      def add_response_type(post)
        post[:response_format] = "JSON"
      end

      def add_customer_data(post, options)
        post[:phone] = options[:billing_address][:phone]
        post[:mail] = options[:email]
      end

      def add_order_data(post, options)
        post[:reference] = options[:order_id]
        post[:concept] = options[:description]
      end

      def add_address(post, creditcard, options)
        post[:address] = options[:billing_address][:address1]
        post[:post_code] = options[:billing_address][:zip]
      end

      def add_creditcard(post, creditcard)
        post[:card_num] = creditcard.number
        post[:card_name] = creditcard.name
        post[:card_type] = card_brand(creditcard)
        post[:card_exp] = "#{sprintf("%02d", creditcard.month)}/#{"#{creditcard.year}"[-2, 2]}"
        post[:card_ccv2] = creditcard.verification_value
      end

      def add_deviceid(post, options)
        post[:deviceid] = options[:deviceid]
      end

      def add_merchant_data(post, options)
        post[:user] = options.fetch(:login)
      end

      def add_amount(post, money, options)
        post[:ammount] = amount(money)
        post[:currency] = options[:currency]
      end

      def card_brand(card)
        brand = super
        ({"master" => "mastercard", "american_express" => "amex"}[brand] || brand)
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(money, parameters)
        url = (test? ? test_url : live_url)
        raw_response = ssl_post(url, post_data(parameters))
        begin
          response = parse(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        Response.new(success?(response),
                     response["message"],
                     response,
                     :test => test?,
                     :authorization => response["code_auth"])
      end

      def success?(response)
        (response["response"] == "ok")
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end
