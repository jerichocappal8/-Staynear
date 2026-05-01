import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import Stripe from "stripe";

admin.initializeApp();

const stripeSecret = defineSecret("STRIPE_SECRET");
const sendgridKey = defineSecret("SENDGRID_KEY");

export const sendBookingEmail = onDocumentUpdated(
{
  document: "bookings/{bookingId}",
  secrets: [sendgridKey],
},
async (event) => {

  const after = event.data?.after.data();
  const before = event.data?.before.data();
  const ref = event.data?.after.ref;

  if (!after || !ref) return;

  console.log("Before:", before?.bookingStatus);
  console.log("After:", after.bookingStatus);

  // 🔑 Only run when status changes to confirmed
  if (
  before?.bookingStatus !== "confirmed" &&
  after.bookingStatus === "confirmed" &&
  after.paymentStatus !== "unpaid"
) {

    // prevent duplicate emails
    if (after.emailSent === true) {
      console.log("Email already sent, skipping.");
      return;
    }

    sgMail.setApiKey(sendgridKey.value());

    const checkIn = after.checkIn.toDate().toDateString();
    const checkOut = after.checkOut.toDate().toDateString();

    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Booking Confirmed – StayNear</title>
</head>
<body style="margin:0;padding:0;background-color:#F8F7F5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">

  <!-- Outer wrapper -->
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F8F7F5;padding:32px 16px;">
    <tr>
      <td align="center">

        <!-- Main container -->
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:600px;width:100%;">

          <!-- ══ HEADER ══ -->
          <tr>
            <td align="center" style="padding-bottom:24px;">
              <table cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="background-color:#F5A623;border-radius:14px;padding:10px 22px;">
                    <span style="font-size:24px;font-weight:800;color:#ffffff;letter-spacing:-0.4px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Stay<span style="color:#1A1A2E;">Near</span></span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ══ CONFIRMED BADGE ══ -->
          <tr>
            <td align="center" style="padding:20px 0 6px;">
              <table cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="background-color:#FFF3E0;border:1px solid #F5A623;border-radius:30px;padding:6px 18px;">
                    <span style="font-size:12px;font-weight:700;color:#F5A623;letter-spacing:0.5px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">✓ &nbsp;BOOKING CONFIRMED</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ══ TITLE ══ -->
          <tr>
            <td align="center" style="padding:10px 16px 6px;">
              <h1 style="margin:0;font-size:26px;font-weight:800;color:#1A1A2E;letter-spacing:-0.5px;line-height:1.25;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Your booking is confirmed!</h1>
            </td>
          </tr>

          <!-- ══ SUBTITLE ══ -->
          <tr>
            <td align="center" style="padding:6px 32px 24px;">
              <p style="margin:0;font-size:14.5px;color:#6B7280;line-height:1.6;text-align:center;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
                Great news! Your reservation at <strong style="color:#1A1A2E;">${after.apartmentName}</strong> has been successfully confirmed and payment received.
              </p>
            </td>
          </tr>

          <!-- ══ BOOKING DETAILS CARD ══ -->
          <tr>
            <td style="padding-bottom:16px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#ffffff;border-radius:20px;border:1px solid #EEECE8;box-shadow:0 4px 20px rgba(0,0,0,0.06);">

                <!-- Card header -->
                <tr>
                  <td style="padding:20px 24px 16px;border-bottom:1px solid #EEECE8;">
                    <span style="font-size:13px;font-weight:700;color:#6B7280;letter-spacing:1px;text-transform:uppercase;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Booking Details</span>
                  </td>
                </tr>

                <!-- Property row -->
                <tr>
                  <td style="padding:18px 24px 0;">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="36" valign="top">
                          <div style="width:34px;height:34px;background-color:#FFF3E0;border-radius:10px;text-align:center;line-height:34px;font-size:16px;">🏠</div>
                        </td>
                        <td style="padding-left:12px;" valign="middle">
                          <span style="font-size:11.5px;color:#6B7280;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Property</span><br/>
                          <span style="font-size:14.5px;font-weight:700;color:#1A1A2E;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">${after.apartmentName}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Divider -->
                <tr><td style="padding:14px 24px 0;"><div style="height:1px;background-color:#EEECE8;"></div></td></tr>

                <!-- Check-in / Check-out row -->
                <tr>
                  <td style="padding:16px 24px 0;">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>

                        <!-- Check-in -->
                        <td width="48%" valign="top">
                          <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color:#F8F7F5;border-radius:14px;border:1px solid #EEECE8;">
                            <tr>
                              <td style="padding:14px 16px;">
                                <span style="font-size:10px;font-weight:700;color:#6B7280;letter-spacing:0.8px;text-transform:uppercase;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Check-in</span><br/>
                                <span style="font-size:13px;font-weight:700;color:#1A1A2E;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">${checkIn}</span>
                              </td>
                            </tr>
                          </table>
                        </td>

                        <!-- Arrow spacer -->
                        <td width="4%" align="center" valign="middle" style="font-size:16px;color:#9CA3AF;padding-bottom:2px;">→</td>

                        <!-- Check-out -->
                        <td width="48%" valign="top">
                          <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color:#F8F7F5;border-radius:14px;border:1px solid #EEECE8;">
                            <tr>
                              <td style="padding:14px 16px;">
                                <span style="font-size:10px;font-weight:700;color:#6B7280;letter-spacing:0.8px;text-transform:uppercase;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Check-out</span><br/>
                                <span style="font-size:13px;font-weight:700;color:#1A1A2E;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">${checkOut}</span>
                              </td>
                            </tr>
                          </table>
                        </td>

                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Divider -->
                <tr><td style="padding:16px 24px 0;"><div style="height:1px;background-color:#EEECE8;"></div></td></tr>

                <!-- Total price highlight -->
                <tr>
                  <td style="padding:18px 24px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#FFF3E0;border-radius:14px;border:1px solid #F5A623;">
                      <tr>
                        <td style="padding:16px 20px;">
                          <table width="100%" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                              <td>
                                <span style="font-size:12px;font-weight:700;color:#F5A623;letter-spacing:0.5px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">TOTAL AMOUNT PAID</span><br/>
                                <span style="font-size:11px;color:#6B7280;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Inclusive of all fees</span>
                              </td>
                              <td align="right">
                                <span style="font-size:26px;font-weight:900;color:#F5A623;letter-spacing:-0.5px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">₱${after.totalPrice}</span>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

              </table>
            </td>
          </tr>

          <!-- ══ WHAT'S NEXT CARD ══ -->
          <tr>
            <td style="padding-bottom:16px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#ffffff;border-radius:20px;border:1px solid #EEECE8;box-shadow:0 4px 20px rgba(0,0,0,0.06);">

                <tr>
                  <td style="padding:20px 24px 16px;border-bottom:1px solid #EEECE8;">
                    <span style="font-size:13px;font-weight:700;color:#6B7280;letter-spacing:1px;text-transform:uppercase;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">What's Next</span>
                  </td>
                </tr>

                <!-- Step 1 -->
                <tr>
                  <td style="padding:16px 24px 0;">
                    <table cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="32" valign="top">
                          <div style="width:28px;height:28px;background-color:#F5A623;border-radius:50%;text-align:center;line-height:28px;font-size:13px;font-weight:800;color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">1</div>
                        </td>
                        <td style="padding-left:12px;" valign="top">
                          <span style="font-size:13.5px;font-weight:700;color:#1A1A2E;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Prepare a valid ID</span><br/>
                          <span style="font-size:12.5px;color:#6B7280;line-height:1.5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Bring a government-issued ID that matches your booking name.</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Step 2 -->
                <tr>
                  <td style="padding:14px 24px 0;">
                    <table cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="32" valign="top">
                          <div style="width:28px;height:28px;background-color:#F5A623;border-radius:50%;text-align:center;line-height:28px;font-size:13px;font-weight:800;color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">2</div>
                        </td>
                        <td style="padding-left:12px;" valign="top">
                          <span style="font-size:13.5px;font-weight:700;color:#1A1A2E;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Contact your host</span><br/>
                          <span style="font-size:12.5px;color:#6B7280;line-height:1.5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Coordinate check-in time and any special arrangements ahead of your arrival.</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Step 3 -->
                <tr>
                  <td style="padding:14px 24px 22px;">
                    <table cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="32" valign="top">
                          <div style="width:28px;height:28px;background-color:#F5A623;border-radius:50%;text-align:center;line-height:28px;font-size:13px;font-weight:800;color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">3</div>
                        </td>
                        <td style="padding-left:12px;" valign="top">
                          <span style="font-size:13.5px;font-weight:700;color:#1A1A2E;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Enjoy your stay 🎉</span><br/>
                          <span style="font-size:12.5px;color:#6B7280;line-height:1.5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Make yourself at home and have a wonderful experience with StayNear.</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

              </table>
            </td>
          </tr>

          <!-- ══ THANK YOU MESSAGE ══ -->
          <tr>
            <td style="padding-bottom:16px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#1A1A2E;border-radius:20px;">
                <tr>
                  <td align="center" style="padding:28px 28px 24px;">
                    <p style="margin:0 0 6px;font-size:20px;font-weight:800;color:#ffffff;letter-spacing:-0.3px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Thank you for choosing StayNear!</p>
                    <p style="margin:0;font-size:13.5px;color:#9CA3AF;line-height:1.6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
                      We're committed to making every stay comfortable, safe, and memorable. If you have any questions before your check-in, don't hesitate to reach out to your host directly through the app.
                    </p>
                    <div style="margin-top:20px;">
                      <span style="display:inline-block;background-color:#F5A623;color:#ffffff;font-size:13px;font-weight:800;padding:11px 28px;border-radius:30px;letter-spacing:0.3px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">Open StayNear App</span>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ══ FOOTER ══ -->
          <tr>
            <td align="center" style="padding-top:8px;padding-bottom:16px;">
              <p style="margin:0 0 4px;font-size:13px;font-weight:800;color:#1A1A2E;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
                Stay<span style="color:#F5A623;">Near</span>
              </p>
              <p style="margin:0 0 6px;font-size:11.5px;color:#9CA3AF;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
                Your trusted rental marketplace in the Philippines
              </p>
              <p style="margin:0;font-size:11px;color:#9CA3AF;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
                StayNear © 2026 &nbsp;·&nbsp; All rights reserved &nbsp;·&nbsp;
                <span style="color:#F5A623;">staynearbooking@gmail.com</span>
              </p>
            </td>
          </tr>

        </table>
        <!-- / Main container -->

      </td>
    </tr>
  </table>
  <!-- / Outer wrapper -->

</body>
</html>

`;

const msg = {
      to: after.guestEmail,
      from: "staynearbooking@gmail.com",
      subject: `Booking Confirmed – ${after.apartmentName} (#${event.params.bookingId})`,
      html,
    };

    try {

      await sgMail.send(msg);
      console.log("Email sent to:", after.guestEmail);

      // mark email as sent
      await ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp()
      });

    } catch (error: any) {
      console.error("SendGrid error:", error);

      if (error.response) {
        console.error(error.response.body);
      }
    }

  }

});
export const createPaymentIntent = onCall(
{
  secrets: [stripeSecret],
},
async (request) => {

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }

  const stripe = new Stripe(stripeSecret.value());
  const amount = Number(request.data.amount);

  if (!Number.isInteger(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "A valid amount is required.");
  }

  const paymentIntent = await stripe.paymentIntents.create({
    amount: amount,
    currency: "php",
    automatic_payment_methods: { enabled: true },
  });

  return {
    clientSecret: paymentIntent.client_secret,
  };

});
