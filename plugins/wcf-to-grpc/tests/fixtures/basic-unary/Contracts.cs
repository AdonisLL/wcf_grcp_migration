using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.ServiceModel;

namespace Fixtures.BasicUnary
{
    [ServiceContract(Namespace = "urn:fixtures:customers:v1")]
    public interface ICustomerService
    {
        [OperationContract(Action = "urn:fixtures:customers:v1/GetCustomer")]
        CustomerRecord GetCustomer(CustomerLookup request);
    }

    [DataContract(Namespace = "urn:fixtures:customers:v1")]
    public sealed class CustomerLookup
    {
        [DataMember(Order = 1, IsRequired = true)]
        public Guid CustomerId { get; set; }

        [DataMember(Order = 2)]
        public bool IncludeHistory { get; set; }
    }

    [DataContract(Namespace = "urn:fixtures:customers:v1")]
    public sealed class CustomerRecord
    {
        [DataMember(Order = 1)]
        public Guid CustomerId { get; set; }

        [DataMember(Order = 2)]
        public string DisplayName { get; set; }

        [DataMember(Order = 3)]
        public int LoyaltyPoints { get; set; }

        [DataMember(Order = 4)]
        public bool Active { get; set; }

        [DataMember(Order = 5)]
        public DateTime CreatedUtc { get; set; }

        [DataMember(Order = 6)]
        public decimal CreditLimit { get; set; }

        [DataMember(Order = 7)]
        public CustomerTier Tier { get; set; }

        [DataMember(Order = 8)]
        public Address MailingAddress { get; set; }

        [DataMember(Order = 9)]
        public List<string> Tags { get; set; }
    }

    [DataContract(Namespace = "urn:fixtures:customers:v1")]
    public sealed class Address
    {
        [DataMember(Order = 1)]
        public string Line1 { get; set; }

        [DataMember(Order = 2)]
        public string City { get; set; }

        [DataMember(Order = 3)]
        public string PostalCode { get; set; }
    }

    [DataContract]
    public enum CustomerTier
    {
        [EnumMember] Standard = 0,
        [EnumMember] Silver = 1,
        [EnumMember] Gold = 2
    }
}
