using System;
using System.Collections.Generic;

namespace Fixtures.BasicUnary
{
    public sealed class CustomerService : ICustomerService
    {
        public CustomerRecord GetCustomer(CustomerLookup request)
        {
            return new CustomerRecord
            {
                CustomerId = request.CustomerId,
                DisplayName = "Fixture Customer",
                LoyaltyPoints = request.IncludeHistory ? 120 : 0,
                Active = true,
                CreatedUtc = new DateTime(2020, 1, 2, 3, 4, 5, DateTimeKind.Utc),
                CreditLimit = 2500.50m,
                Tier = CustomerTier.Gold,
                MailingAddress = new Address
                {
                    Line1 = "1 Fixture Way",
                    City = "Example",
                    PostalCode = "00001"
                },
                Tags = new List<string> { "sample", "legacy-wcf" }
            };
        }
    }
}
