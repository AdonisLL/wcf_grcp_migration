using System;
using System.ServiceModel;

namespace Fixtures.BasicUnary
{
    internal static class Program
    {
        private static void Main()
        {
            using (var host = new ServiceHost(typeof(CustomerService)))
            {
                host.Open();

                var factory = new ChannelFactory<ICustomerService>("CustomerClient");
                var client = factory.CreateChannel();
                var customer = client.GetCustomer(new CustomerLookup
                {
                    CustomerId = Guid.Parse("11111111-1111-1111-1111-111111111111"),
                    IncludeHistory = true
                });

                Console.WriteLine(customer.DisplayName);
                ((IClientChannel)client).Close();
                factory.Close();
            }
        }
    }
}
