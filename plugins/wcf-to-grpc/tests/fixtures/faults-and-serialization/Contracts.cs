using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.ServiceModel;

namespace Fixtures.FaultsAndSerialization
{
    [ServiceContract(Namespace = "urn:fixtures:invoices:v2")]
    public interface IInvoiceService
    {
        [OperationContract]
        [FaultContract(typeof(ValidationFault), Action = "urn:fixtures:invoices:v2/ValidationFault")]
        Invoice GetInvoice(InvoiceQuery query);
    }

    [DataContract]
    public sealed class InvoiceQuery
    {
        [DataMember(Order = 1, IsRequired = true)]
        public string InvoiceNumber { get; set; }
    }

    [DataContract]
    public sealed class ValidationFault
    {
        [DataMember(Order = 1)]
        public string Code { get; set; }

        [DataMember(Order = 2)]
        public string Message { get; set; }

        [DataMember(Order = 3)]
        public Dictionary<string, string> FieldErrors { get; set; }
    }

    [DataContract]
    public sealed class Invoice
    {
        [DataMember(Order = 1)]
        public string InvoiceNumber { get; set; }

        [DataMember(Order = 2)]
        public decimal Amount { get; set; }

        [DataMember(Order = 3, EmitDefaultValue = false)]
        public decimal? DiscountAmount { get; set; }

        [DataMember(Order = 4, EmitDefaultValue = false)]
        public DateTime? DueDate { get; set; }

        [DataMember(Order = 5)]
        public DateTime CreatedUtc { get; set; }

        [DataMember(Order = 6, EmitDefaultValue = false)]
        public bool Archived { get; set; }

        [DataMember(Order = 7, EmitDefaultValue = false)]
        public InvoiceState State { get; set; }

        [DataMember(Order = 8)]
        public PaymentMethod Payment { get; set; }
    }

    [DataContract]
    public enum InvoiceState
    {
        [EnumMember] Draft = 0,
        [EnumMember] Issued = 1,
        [EnumMember] Paid = 2,
        [EnumMember] Cancelled = 9
    }

    [DataContract]
    [KnownType(typeof(CardPayment))]
    [KnownType(typeof(BankTransferPayment))]
    public abstract class PaymentMethod
    {
        [DataMember(Order = 1)]
        public string Reference { get; set; }
    }

    [DataContract]
    public sealed class CardPayment : PaymentMethod
    {
        [DataMember(Order = 2)]
        public string LastFour { get; set; }
    }

    [DataContract]
    public sealed class BankTransferPayment : PaymentMethod
    {
        [DataMember(Order = 2)]
        public string BankCode { get; set; }
    }
}
