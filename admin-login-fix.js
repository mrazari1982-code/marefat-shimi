// Admin login helper — loaded only by admin.html when included.
// Kept separate so login logic can be tested without touching the dashboard UI.
(function(){
  window.marefatAdminLogin = async function(supabaseClient, email, password){
    if(!supabaseClient) throw new Error('Supabase client is not initialized.');
    if(!email || !password) throw new Error('ایمیل و رمز عبور را وارد کنید.');
    const result = await supabaseClient.auth.signInWithPassword({email, password});
    if(result.error) throw result.error;
    const staff = await supabaseClient.rpc('v5_is_staff');
    if(staff.error) throw staff.error;
    if(staff.data !== true) throw new Error('این حساب دسترسی مدیر ندارد.');
    return result.data;
  };
})();
