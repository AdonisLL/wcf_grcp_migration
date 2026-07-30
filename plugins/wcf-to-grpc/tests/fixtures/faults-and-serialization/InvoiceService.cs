using System;
using System.Collections.Generic;
using System.ServiceModel;

namespace Fixtures.FaultsAndSerialization
{
    public sealed class InvoiceService : IInvoiceService
    {
        public Invoice GetInvoice(InvoiceQuery query)
        {
            if (string.IsNullOrWhiteSpace(query.InvoiceNumber))
            {
                var detail = new ValidationFault
                {
                    Code = "invoice_number_required",
                    Message = "Invoice number is required.",
                    FieldErrors = new Dictionary<string, string>
                    {
                        ["invoiceNumber"] = "required"
                    }
                };
                throw new FaultException<ValidationFault>(
                    detail,
                    new FaultReason(detail.Message),
                    new FaultCode("Sender"));
            }

            return new Invoice
            {
                InvoiceNumber = query.InvoiceNumber,
                Amount = 1234567890.1234m,
                DiscountAmount = null,
                DueDate = null,
                CreatedUtc = DateTime.SpecifyKind(new DateTime(2024, 2, 29, 8, 30, 0), DateTimeKind.Utc),
                Archived = false,
                State = InvoiceState.Issued,
                Payment = new CardPayment { Reference = "pay-42", LastFour = "4242" }
            };
        }
    }
}
