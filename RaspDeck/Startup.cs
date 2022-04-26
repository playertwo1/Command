using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;
using System.IO;
using System.Reflection;

namespace RaspDeck
{
  class Startup
  {
    string appName = System.Reflection.Assembly.GetExecutingAssembly().GetName().Name;
    string version = "v" + Assembly.GetExecutingAssembly().GetName().Version.ToString().Replace(".", "").Replace("0", "");
    readonly string MyAllowSpecificOrigins = "_myAllowSpecificOrigins";
    public Startup(IConfiguration configuration)
    {
      Configuration = configuration;
    }
    public IConfiguration Configuration { get; }
    public void ConfigureServices(IServiceCollection services)
    {
      services.AddControllers();
      services.AddSwaggerGen(c =>
      {
        c.SwaggerDoc("v1", new OpenApiInfo { Title = appName, Version = version });
      });
      services.AddCors(options =>
      {
        options.AddPolicy(name: MyAllowSpecificOrigins,
                          builder =>
                          {
                            builder.WithOrigins("http://localhost:5000");
                          });
      });
    }
    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
      if (env.IsDevelopment())
      {
        app.UseDeveloperExceptionPage();
        app.UseSwagger();
        app.UseCors(MyAllowSpecificOrigins);
        app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", appName + " " + version));
      }
      app.UseFileServer(new FileServerOptions
      {
        FileProvider = new PhysicalFileProvider(
                    Path.Combine(Directory.GetCurrentDirectory(), "Static")),
        RequestPath = "",
        EnableDefaultFiles = true
      });
      app.UseRouting();
      app.UseEndpoints(endpoints =>
      {
        endpoints.MapControllers();
      });
    }
  }
}
